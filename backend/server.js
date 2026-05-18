const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const dotenv = require('dotenv');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Groq = require('groq-sdk');
const twilio = require('twilio');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'webgenixx_secret_key_12345';

// Core State: Is MongoDB Connected?
let isMongoConnected = false;

// Ensure local fallback data directory exists
const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const USERS_FILE = path.join(DATA_DIR, 'users.json');
const LEADS_FILE = path.join(DATA_DIR, 'leads.json');

// Helper to read JSON files safely (Fallback DB Mode)
const readJsonFile = (filePath, defaultData = []) => {
  try {
    if (!fs.existsSync(filePath)) {
      fs.writeFileSync(filePath, JSON.stringify(defaultData, null, 2));
      return defaultData;
    }
    const data = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error(`Error reading ${filePath}:`, error);
    return defaultData;
  }
};

// Helper to write JSON files safely (Fallback DB Mode)
const writeJsonFile = (filePath, data) => {
  try {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    console.error(`Error writing ${filePath}:`, error);
    return false;
  }
};

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
// Bypass ngrok browser warning page for webhook requests
app.use((req, res, next) => {
  res.setHeader('ngrok-skip-browser-warning', 'true');
  next();
});
app.use(bodyParser.urlencoded({ extended: true }));


// ================= MONGOOSE SCHEMAS & MODELS =================

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true, index: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

const LeadSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone: { type: String, required: true, index: true },
  businessType: { type: String, default: 'General Business' },
  city: { type: String, default: 'Unknown' },
  status: { 
    type: String, 
    default: 'Pending',
    enum: ['Pending', 'Calling...', 'In Conversation', 'Interested', 'Callback Later', 'Rejected']
  },
  pitch: { type: String, default: '' },
  lastCalled: { type: Date, default: null },
  notes: { type: String, default: '' },
  recordingUrl: { type: String, default: '' }
});

const User = mongoose.model('User', UserSchema);
const Lead = mongoose.model('Lead', LeadSchema);


// Connect to MongoDB with Auto Fallback
const MONGO_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/webgenixx_ai_caller';

mongoose.connect(MONGO_URI)
  .then(() => {
    console.log(`=======================================================`);
    console.log(`  MONGODB CONNECTED SUCCESS: ${MONGO_URI}`);
    console.log(`=======================================================`);
    isMongoConnected = true;
    seedDatabase();
  })
  .catch(err => {
    console.log(`=======================================================`);
    console.log(`  MONGODB SERVER OFFLINE. RUNNING RESILIENT FILE DB MODE`);
    console.log(`  Details: ${err.message}`);
    console.log(`=======================================================`);
    isMongoConnected = false;
    seedFallbackData(); // Seed json files if offline
  });


// ================= DATA SEEDING LOGIC =================

// Seed MongoDB data
async function seedDatabase() {
  try {
    const userCount = await User.countDocuments();
    if (userCount === 0) {
      const salt = bcrypt.genSaltSync(10);
      const hashedPassword = bcrypt.hashSync('webgenixx123', salt);
      await User.create({
        name: 'Admin Founder',
        email: 'founder@webgenixx.com',
        password: hashedPassword
      });
      console.log('[MONGO] Seeded default admin user: founder@webgenixx.com / webgenixx123');
    }

    const leadCount = await Lead.countDocuments();
    if (leadCount === 0) {
      await Lead.insertMany(getSampleLeads());
      console.log('[MONGO] Seeded sample campaign leads.');
    }
  } catch (error) {
    console.error('Error seeding MongoDB:', error);
  }
}

// Seed JSON fallback files
function seedFallbackData() {
  const users = readJsonFile(USERS_FILE);
  if (users.length === 0) {
    const salt = bcrypt.genSaltSync(10);
    const hashedPassword = bcrypt.hashSync('webgenixx123', salt);
    users.push({
      id: '1',
      name: 'Admin Founder',
      email: 'founder@webgenixx.com',
      password: hashedPassword,
      createdAt: new Date().toISOString()
    });
    writeJsonFile(USERS_FILE, users);
    console.log('[FILE] Seeded default admin user: founder@webgenixx.com / webgenixx123');
  }

  const leads = readJsonFile(LEADS_FILE);
  if (leads.length === 0) {
    writeJsonFile(LEADS_FILE, getSampleLeads().map((l, index) => ({ id: `l_${index + 1}`, ...l })));
    console.log('[FILE] Seeded sample leads');
  }
}

function getSampleLeads() {
  return [
    {
      name: 'Venkata Rao',
      phone: '+919876543210',
      businessType: 'Hair Salon & Spa',
      city: 'Hyderabad',
      status: 'Interested',
      pitch: 'Hello, Webgenixx nunchi call chesthunam. Mee salon ki website ledu ani gamanincham. Online bookings and customer reach improve cheyyadaniki professional website create chestham.',
      lastCalled: new Date(Date.now() - 4 * 3600000).toISOString(),
      notes: 'Very interested in booking system'
    },
    {
      name: 'Anjali Bakery',
      phone: '+918765432109',
      businessType: 'Cake Shop',
      city: 'Vijayawada',
      status: 'Callback Later',
      pitch: 'Hello, Webgenixx nunchi call chesthunam. Mee bakery products dynamic digital catalog format lo cell phone customers ki purchase cheyadaniki customize portal ready chestham.',
      lastCalled: new Date(Date.now() - 2 * 3600000).toISOString(),
      notes: 'Call back tomorrow at 3 PM'
    },
    {
      name: 'Srinivas Builders',
      phone: '+917654321098',
      businessType: 'Real Estate Developer',
      city: 'Visakhapatnam',
      status: 'Pending',
      pitch: '',
      lastCalled: null,
      notes: ''
    },
    {
      name: 'Prasad Sweets',
      phone: '+916543210987',
      businessType: 'Sweet Stall',
      city: 'Guntur',
      status: 'Rejected',
      pitch: 'Hello, Prasad garu. Online orders direct ga delivery and payments track cheyyadaniki modern e-commerce setup chestham Webgenixx dwara.',
      lastCalled: new Date(Date.now() - 6 * 3600000).toISOString(),
      notes: 'Says too busy, does not need online sales'
    },
    {
      name: 'Jyothi Diagnostics',
      phone: '+919988776655',
      businessType: 'Medical Lab',
      city: 'Tirupati',
      status: 'Pending',
      pitch: '',
      lastCalled: null,
      notes: ''
    }
  ];
}


// JWT Authentication Middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) return res.status(401).json({ error: 'Access token required' });

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid or expired token' });
    req.user = user;
    next();
  });
};


// ================= AUTHENTICATION ENDPOINTS =================

// Register User
app.post('/api/auth/register', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'Please provide all fields' });
  }

  const salt = bcrypt.genSaltSync(10);
  const hashedPassword = bcrypt.hashSync(password, salt);

  if (isMongoConnected) {
    try {
      const existingUser = await User.findOne({ email: email.toLowerCase() });
      if (existingUser) {
        return res.status(400).json({ error: 'User with this email already exists' });
      }

      const newUser = await User.create({
        name,
        email: email.toLowerCase(),
        password: hashedPassword
      });

      const token = jwt.sign({ id: newUser._id, email: newUser.email }, JWT_SECRET, { expiresIn: '7d' });
      res.status(201).json({
        message: 'User registered successfully in MongoDB',
        token,
        user: { id: newUser._id, name: newUser.name, email: newUser.email }
      });
    } catch (e) {
      res.status(500).json({ error: 'Database registration failed: ' + e.message });
    }
  } else {
    // Fallback File DB
    const users = readJsonFile(USERS_FILE);
    if (users.find(u => u.email.toLowerCase() === email.toLowerCase())) {
      return res.status(400).json({ error: 'User with this email already exists' });
    }

    const newUser = {
      id: Date.now().toString(),
      name,
      email: email.toLowerCase(),
      password: hashedPassword,
      createdAt: new Date().toISOString()
    };

    users.push(newUser);
    writeJsonFile(USERS_FILE, users);

    const token = jwt.sign({ id: newUser.id, email: newUser.email }, JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({
      message: 'User registered successfully in Fallback DB',
      token,
      user: { id: newUser.id, name: newUser.name, email: newUser.email }
    });
  }
});

// Login User
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Please provide email and password' });
  }

  if (isMongoConnected) {
    try {
      const user = await User.findOne({ email: email.toLowerCase() });
      if (!user || !bcrypt.compareSync(password, user.password)) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = jwt.sign({ id: user._id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
      res.json({
        message: 'Login successful via MongoDB',
        token,
        user: { id: user._id, name: user.name, email: user.email }
      });
    } catch (e) {
      res.status(500).json({ error: 'Database login query failed: ' + e.message });
    }
  } else {
    // Fallback File DB
    const users = readJsonFile(USERS_FILE);
    const user = users.find(u => u.email.toLowerCase() === email.toLowerCase());

    if (!user || !bcrypt.compareSync(password, user.password)) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
    res.json({
      message: 'Login successful via Fallback DB',
      token,
      user: { id: user.id, name: user.name, email: user.email }
    });
  }
});

// Get Current User Profile
app.get('/api/auth/profile', authenticateToken, async (req, res) => {
  if (isMongoConnected) {
    try {
      const user = await User.findById(req.user.id);
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json({ user: { id: user._id, name: user.name, email: user.email } });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  } else {
    const users = readJsonFile(USERS_FILE);
    const user = users.find(u => u.id === req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ user: { id: user.id, name: user.name, email: user.email } });
  }
});


// ================= LEAD CAMPAIGN ENDPOINTS =================

// Get all leads
app.get('/api/leads', authenticateToken, async (req, res) => {
  if (isMongoConnected) {
    try {
      const leads = await Lead.find({});
      // Map MongoDB _id to standard 'id' field for Flutter client compatibility
      const mapped = leads.map(l => ({
        id: l._id.toString(),
        name: l.name,
        phone: l.phone,
        businessType: l.businessType,
        city: l.city,
        status: l.status,
        pitch: l.pitch,
        lastCalled: l.lastCalled,
        notes: l.notes
      }));
      res.json(mapped);
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  } else {
    const leads = readJsonFile(LEADS_FILE);
    res.json(leads);
  }
});

// Bulk Import Leads
app.post('/api/leads/bulk', authenticateToken, async (req, res) => {
  const newLeads = req.body.leads;
  if (!Array.isArray(newLeads)) {
    return res.status(400).json({ error: 'Leads should be an array' });
  }

  let addedCount = 0;
  let duplicateCount = 0;

  if (isMongoConnected) {
    try {
      const existingLeads = await Lead.find({});
      const toInsert = [];

      newLeads.forEach(lead => {
        const normalizedPhone = lead.phone.replace(/\s+/g, '');
        const isDuplicate = existingLeads.some(l => l.phone.replace(/\s+/g, '') === normalizedPhone);
        
        if (!isDuplicate && lead.phone && lead.name) {
          toInsert.push({
            name: lead.name,
            phone: lead.phone,
            businessType: lead.businessType || 'General Business',
            city: lead.city || 'Unknown',
            status: lead.status || 'Pending',
            pitch: '',
            notes: ''
          });
          addedCount++;
        } else {
          duplicateCount++;
        }
      });

      if (toInsert.length > 0) {
        await Lead.insertMany(toInsert);
      }

      res.json({
        message: `Leads imported into MongoDB successfully. Added: ${addedCount}, Duplicates ignored: ${duplicateCount}`,
        addedCount,
        duplicateCount
      });
    } catch (e) {
      res.status(500).json({ error: 'MongoDB bulk write failed: ' + e.message });
    }
  } else {
    // Fallback File DB
    const leads = readJsonFile(LEADS_FILE);
    newLeads.forEach(lead => {
      const normalizedPhone = lead.phone.replace(/\s+/g, '');
      const isDuplicate = leads.some(l => l.phone.replace(/\s+/g, '') === normalizedPhone);
      
      if (!isDuplicate && lead.phone && lead.name) {
        leads.push({
          id: 'l_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
          name: lead.name,
          phone: lead.phone,
          businessType: lead.businessType || 'General Business',
          city: lead.city || 'Unknown',
          status: lead.status || 'Pending',
          pitch: '',
          lastCalled: null,
          notes: ''
        });
        addedCount++;
      } else {
        duplicateCount++;
      }
    });

    writeJsonFile(LEADS_FILE, leads);
    res.json({
      message: `Leads imported into Fallback DB successfully. Added: ${addedCount}, Duplicates ignored: ${duplicateCount}`,
      addedCount,
      duplicateCount
    });
  }
});

// Single lead updates
app.patch('/api/leads/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;

  if (isMongoConnected) {
    try {
      const updated = await Lead.findByIdAndUpdate(
        id,
        { $set: req.body },
        { new: true }
      );
      if (!updated) return res.status(404).json({ error: 'Lead not found in MongoDB' });
      
      res.json({
        id: updated._id.toString(),
        name: updated.name,
        phone: updated.phone,
        businessType: updated.businessType,
        city: updated.city,
        status: updated.status,
        pitch: updated.pitch,
        lastCalled: updated.lastCalled,
        notes: updated.notes
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  } else {
    // Fallback File DB
    const leads = readJsonFile(LEADS_FILE);
    const leadIndex = leads.findIndex(l => l.id === id);

    if (leadIndex === -1) {
      return res.status(404).json({ error: 'Lead not found in fallback' });
    }

    const updatedLead = { ...leads[leadIndex], ...req.body };
    leads[leadIndex] = updatedLead;

    writeJsonFile(LEADS_FILE, leads);
    res.json(updatedLead);
  }
});

// Clear all leads
app.delete('/api/leads', authenticateToken, async (req, res) => {
  if (isMongoConnected) {
    try {
      await Lead.deleteMany({});
      res.json({ message: 'All leads successfully deleted from MongoDB' });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  } else {
    writeJsonFile(LEADS_FILE, []);
    res.json({ message: 'All leads cleared from Fallback DB' });
  }
});


// ================= ANALYTICS & DASHBOARD =================

app.get('/api/analytics', authenticateToken, async (req, res) => {
  let leads = [];
  
  if (isMongoConnected) {
    try {
      leads = await Lead.find({});
    } catch (e) {
      console.error('Mongo analytics query failed, fallback active:', e);
      leads = readJsonFile(LEADS_FILE);
    }
  } else {
    leads = readJsonFile(LEADS_FILE);
  }

  const total = leads.length;
  const completed = leads.filter(l => l.status !== 'Pending' && l.status !== 'Calling...').length;
  const interested = leads.filter(l => l.status === 'Interested').length;
  const callback = leads.filter(l => l.status === 'Callback Later').length;
  const rejected = leads.filter(l => l.status === 'Rejected').length;
  
  const conversionRate = total > 0 ? ((interested / total) * 100).toFixed(1) : '0';

  // Niche distribution count
  const niches = {};
  leads.forEach(l => {
    const n = l.businessType || 'General';
    niches[n] = (niches[n] || 0) + 1;
  });

  // Success rate by niche
  const nicheSuccess = {};
  leads.forEach(l => {
    const n = l.businessType || 'General';
    if (!nicheSuccess[n]) {
      nicheSuccess[n] = { total: 0, interested: 0 };
    }
    nicheSuccess[n].total++;
    if (l.status === 'Interested') {
      nicheSuccess[n].interested++;
    }
  });

  const nichePerformance = Object.keys(nicheSuccess).map(n => ({
    niche: n,
    total: nicheSuccess[n].total,
    interested: nicheSuccess[n].interested,
    percentage: nicheSuccess[n].total > 0 ? Math.round((nicheSuccess[n].interested / nicheSuccess[n].total) * 100) : 0
  })).sort((a, b) => b.percentage - a.percentage);

  // Daily calling history curves
  const callingHistory = [
    { day: 'Mon', calls: 12, conversions: 2 },
    { day: 'Tue', calls: 18, conversions: 4 },
    { day: 'Wed', calls: 24, conversions: 5 },
    { day: 'Thu', calls: 15, conversions: 3 },
    { day: 'Fri', calls: 30, conversions: 8 },
    { day: 'Sat', calls: completed, conversions: interested }
  ];

  res.json({
    totalLeads: total,
    callsCompleted: completed,
    interestedLeads: interested,
    callbackRequests: callback,
    rejectedLeads: rejected,
    conversionRate: parseFloat(conversionRate),
    nichePerformance,
    callingHistory
  });
});


// ================= GROQ AI COLD SCRIPT GENERATION =================

app.post('/api/ai/generate-pitch', authenticateToken, async (req, res) => {
  const { name, businessType, city } = req.body;
  if (!name || !businessType || !city) {
    return res.status(400).json({ error: 'Provide name, businessType, and city' });
  }

  // Always generate in Telugu
  const lang = 'Telugu';

  const isGroqConfigured = process.env.GROQ_API_KEY && 
                           process.env.GROQ_API_KEY !== 'gsk_your_groq_api_key_here' &&
                           process.env.GROQ_API_KEY !== '';
  
  if (!isGroqConfigured) {
    console.log('Groq API Key not configured. Using offline fallback script.');
    const fallbackPitch = generateLocalPitch(name, businessType, city, lang);
    return res.json({ pitch: fallbackPitch, model: 'Offline Webgenixx Sales Engine v1' });
  }

  try {
    const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
    
    const prompt = `Create a highly engaging, professional, and friendly outbound cold-calling sales pitch strictly in Telugu language (use Telugu script only) for a web development agency named "Webgenixx".
      Lead Information:
      - Owner Name: ${name}
      - Business Name/Type: ${businessType}
      - City: ${city}

      Pitch guidelines:
      1. Greet them respectfully using 'నమస్కారం ${name} గారు'.
      2. Mention that we noticed they don't have a modern business website, or that their competitor in ${city} does.
      3. Explain how Webgenixx can build an amazing website to automate bookings, drive online reach, and double their customers.
      4. Keep it ultra-concise (under 75 words) so it can be spoken in under 30 seconds by a Telugu text-to-speech engine.
      5. End with a warm closing like 'మీకు ధన్యవాదాలు'.
      Return ONLY the final spoken Telugu script text. No English. No intro/outro commentary.`;

    const completion = await groq.chat.completions.create({
      messages: [{ role: 'user', content: prompt }],
      model: 'llama-3.1-8b-instant',
      temperature: 0.7,
      max_tokens: 200
    });

    const pitch = completion.choices[0]?.message?.content?.trim() || generateLocalPitch(name, businessType, city, lang);
    res.json({ pitch, model: 'Groq Llama-3 (Telugu)' });
  } catch (error) {
    console.error('Groq script generation failed:', error);
    res.json({
      pitch: generateLocalPitch(name, businessType, city, lang),
      model: 'Offline Fallback Engine (API Error)'
    });
  }
});

function generateLocalPitch(name, businessType, city, language) {
  // Always generate Telugu pitch
  return `నమస్కారం ${name} గారు! నేను Webgenixx డిజిటల్ ఏజెన్సీ నుండి కాల్ చేస్తున్నాను. మీ ${businessType} వ్యాపారానికి ప్రొఫెషనల్ వెబ్సైట్ లేదని గమనించాము. ${city} లో మీ కస్టమర్లను రెట్టింపు చేయడానికి మేము అద్భుతమైన వెబ్సైట్ తయారు చేస్తాము. మీకు ధన్యవాదాలు!`;
}


// ================= TWILIO API CALL TRIGGERING & WEBHOOKS =================

// Endpoint to trigger outbound call
app.post('/api/calls/trigger', authenticateToken, async (req, res) => {
  const { leadId, language, simulated } = req.body;
  if (!leadId) {
    return res.status(400).json({ error: 'leadId is required' });
  }

  let lead = null;
  let leads = [];

  if (isMongoConnected) {
    try {
      lead = await Lead.findById(leadId);
    } catch (_) {}
  } else {
    leads = readJsonFile(LEADS_FILE);
    lead = leads.find(l => l.id === leadId);
  }

  if (!lead) {
    return res.status(404).json({ error: 'Lead not found' });
  }

  const lang = language || 'English';
  
  if (!lead.pitch) {
    lead.pitch = generateLocalPitch(lead.name, lead.businessType, lead.city, lang);
  }

  const isTwilioConfigured = process.env.TWILIO_ACCOUNT_SID && 
                             process.env.TWILIO_ACCOUNT_SID !== 'ACyour_twilio_account_sid_here' && 
                             process.env.TWILIO_AUTH_TOKEN &&
                             process.env.TWILIO_AUTH_TOKEN !== 'your_twilio_auth_token_here';

  if (simulated || !isTwilioConfigured) {
    console.log(`[SIMULATOR] Initiating simulated outbound call to ${lead.name} (${lead.phone})`);
    
    // Update local lead status
    if (isMongoConnected) {
      await Lead.findByIdAndUpdate(leadId, {
        $set: {
          lastCalled: new Date(),
          status: 'Calling...'
        }
      });
    } else {
      const idx = leads.findIndex(l => l.id === leadId);
      leads[idx].lastCalled = new Date().toISOString();
      leads[idx].status = 'Calling...';
      writeJsonFile(LEADS_FILE, leads);
    }

    // Trigger simulation lifecycle async
    simulateCallLifecycle(leadId);

    return res.json({
      message: 'Call simulated successfully (Sandbox Mode active)',
      callSid: 'sim_sid_' + Math.random().toString(36).substr(2, 9),
      status: 'Calling...',
      simulated: true
    });
  }

  // Real Twilio Call
  try {
    const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const resolvedId = (lead._id || lead.id).toString();
    const twimlUrl = `${process.env.BASE_URL}/api/calls/twiml/${resolvedId}?lang=Telugu`;

    console.log(`[TWILIO] Placing real outbound call to ${lead.phone}`);
    console.log(`[TWILIO] TwiML webhook: ${twimlUrl}`);

    const call = await client.calls.create({
      url: twimlUrl,
      to: lead.phone,
      from: process.env.TWILIO_PHONE_NUMBER
    });

    if (isMongoConnected) {
      await Lead.findByIdAndUpdate(leadId, {
        $set: {
          lastCalled: new Date(),
          status: 'Calling...'
        }
      });
    } else {
      const idx = leads.findIndex(l => l.id === leadId);
      leads[idx].lastCalled = new Date().toISOString();
      leads[idx].status = 'Calling...';
      writeJsonFile(LEADS_FILE, leads);
    }

    res.json({
      message: 'Twilio outbound call placed successfully',
      callSid: call.sid,
      status: 'Calling...',
      simulated: false
    });
  } catch (error) {
    console.error('Twilio calling error:', error);
    res.status(500).json({
      error: 'Failed to initiate Twilio call. Check backend configuration or run in Simulator/Sandbox mode.',
      details: error.message
    });
  }
});

// TwiML Webhook endpoint
app.post('/api/calls/twiml/:leadId', async (req, res) => {
  const { leadId } = req.params;

  let lead = null;
  if (isMongoConnected) {
    try {
      lead = await Lead.findByIdAndUpdate(
        leadId,
        { $set: { status: 'In Conversation' } },
        { new: true }
      );
    } catch (e) {
      console.error('[TWIML] MongoDB findById error:', e.message);
    }
  } else {
    const leads = readJsonFile(LEADS_FILE);
    const idx = leads.findIndex(l => l.id === leadId);
    if (idx !== -1) {
      leads[idx].status = 'In Conversation';
      writeJsonFile(LEADS_FILE, leads);
      lead = leads[idx];
    }
  }

  console.log(`[TWIML] leadId=${leadId}, found=${!!lead}, pitch=${lead?.pitch?.substring(0, 40)}`);

  if (!lead || !lead.pitch) {
    // Fallback: generate a default Telugu pitch if lead not found
    const response = new twilio.twiml.VoiceResponse();
    response.say({ voice: 'Polly.Kajal', language: 'te-IN' },
      'నమస్కారం! మేము Webgenixx డిజిటల్ ఏజెన్సీ నుండి కాల్ చేస్తున్నాము. మీ వ్యాపారానికి వెబ్సైట్ తయారు చేయడానికి మేము సహాయం చేస్తాము. మీకు ధన్యవాదాలు!'
    );
    response.hangup();
    res.type('text/xml');
    return res.send(response.toString());
  }

  const response = new twilio.twiml.VoiceResponse();
  // Always use Telugu voice
  const voice = 'Polly.Kajal';
  const twilioLang = 'te-IN';

  // Wrap everything in a Gather to silently absorb any key presses
  const gather = response.gather({
    numDigits: 1,
    action: `${process.env.BASE_URL}/api/calls/keypress/${lead._id || lead.id}`,
    method: 'POST',
    timeout: 30,
  });

  // Speak the personalized sales pitch inside gather
  gather.say({ voice, language: twilioLang }, lead.pitch);

  // Telugu closing message inside gather
  gather.say({ voice, language: twilioLang },
    'మీ వ్యాపారానికి వెబ్సైట్ డిజైన్ చేయడానికి మా టీమ్ త్వరలో మీకు కాంటాక్ట్ చేస్తుంది. మీకు ధన్యవాదాలు!'
  );

  // Mark lead as Callback Later after pitch delivery
  if (isMongoConnected) {
    try {
      await Lead.findByIdAndUpdate(lead._id || lead.id, {
        $set: { status: 'Callback Later', notes: 'Pitch delivered via Twilio call. Recording in progress.' }
      });
    } catch (_) {}
  } else {
    const leads = readJsonFile(LEADS_FILE);
    const idx = leads.findIndex(l => l.id === (lead._id || lead.id)?.toString());
    if (idx !== -1) {
      leads[idx].status = 'Callback Later';
      leads[idx].notes = 'Pitch delivered via Twilio call. Recording in progress.';
      writeJsonFile(LEADS_FILE, leads);
    }
  }

  response.hangup();

  res.type('text/xml');
  res.send(response.toString());
});

// Keypress handler — absorbs any key the user presses, just hangs up gracefully
app.post('/api/calls/keypress/:leadId', async (req, res) => {
  const { leadId } = req.params;
  const digit = req.body.Digits;
  console.log(`[KEYPRESS] Lead ${leadId} pressed: ${digit}`);

  const response = new twilio.twiml.VoiceResponse();
  response.say({ voice: 'Polly.Kajal', language: 'te-IN' },
    'మీకు ధన్యవాదాలు! మా టీమ్ త్వరలో మీకు కాంటాక్ట్ చేస్తుంది.'
  );
  response.hangup();
  res.type('text/xml');
  res.send(response.toString());
});

// Recording completed webhook — saves recording URL to lead
app.post('/api/calls/recording/:leadId', async (req, res) => {
  const { leadId } = req.params;
  const recordingUrl = req.body.RecordingUrl;
  const recordingSid = req.body.RecordingSid;

  console.log(`[RECORDING] Lead ${leadId} — Recording URL: ${recordingUrl}`);

  const recordingNote = `Recording: ${recordingUrl}.mp3 (SID: ${recordingSid})`;

  if (isMongoConnected) {
    try {
      await Lead.findByIdAndUpdate(leadId, {
        $set: { notes: recordingNote, recordingUrl: `${recordingUrl}.mp3` }
      });
    } catch (_) {}
  } else {
    const leads = readJsonFile(LEADS_FILE);
    const idx = leads.findIndex(l => l.id === leadId);
    if (idx !== -1) {
      leads[idx].notes = recordingNote;
      leads[idx].recordingUrl = `${recordingUrl}.mp3`;
      writeJsonFile(LEADS_FILE, leads);
    }
  }

  res.sendStatus(200);
});

// Recording status callback
app.post('/api/calls/recording-status/:leadId', async (req, res) => {
  const { leadId } = req.params;
  const status = req.body.RecordingStatus;
  const recordingUrl = req.body.RecordingUrl;
  console.log(`[RECORDING STATUS] Lead ${leadId} — Status: ${status}, URL: ${recordingUrl}`);
  res.sendStatus(200);
});

// Gather webhook endpoint
app.post('/api/calls/gather/:leadId', async (req, res) => {
  const { leadId } = req.params;
  const digit = req.body.Digits;
  const lang = req.query.lang || 'English';

  const response = new twilio.twiml.VoiceResponse();
  const voice = lang === 'Telugu' ? 'Polly.Kajal' : 'Polly.Aditi';
  const twilioLang = lang === 'Telugu' ? 'te-IN' : 'en-IN';

  let nextStatus = 'Rejected';
  let notes = 'Lead declined pitch';
  let thankYouMsg = 'Thank you for your response. Have a great day.';

  if (digit === '1') {
    nextStatus = 'Interested';
    notes = 'Lead pressed 1: Highly interested, request demo website mockup!';
    thankYouMsg = lang === 'Telugu' 
      ? 'Chala thanks andi! Maa web design team ventane mee tho matladi free website structure pampisthundi.' 
      : 'Excellent! Thank you for your interest. Our Webgenixx team will email you a beautiful custom mockup in 24 hours.';
  } else if (digit === '2') {
    nextStatus = 'Callback Later';
    notes = 'Lead pressed 2: Busy, request follow-up callback tomorrow';
    thankYouMsg = lang === 'Telugu'
      ? 'Tappakunda, memu repu thirigi mee anukulaina samayaniki call chestham. Dhanyavadalu!'
      : 'Sure, we have scheduled a convenient follow-up call for tomorrow. Thank you!';
  } else {
    nextStatus = 'Rejected';
    notes = `Lead pressed ${digit || 'none'}: Opted out / Not interested`;
    thankYouMsg = lang === 'Telugu'
      ? 'Sare andi, mee time spend chesinanduku dhanyavadalu.'
      : 'We respect your preference. Thank you for your time today.';
  }

  // Update DB lead status
  if (isMongoConnected) {
    try {
      await Lead.findByIdAndUpdate(leadId, {
        $set: {
          status: nextStatus,
          notes: notes
        }
      });
    } catch (_) {}
  } else {
    const leads = readJsonFile(LEADS_FILE);
    const idx = leads.findIndex(l => l.id === leadId);
    if (idx !== -1) {
      leads[idx].status = nextStatus;
      leads[idx].notes = notes;
      writeJsonFile(LEADS_FILE, leads);
    }
  }

  response.say({ voice, language: twilioLang }, thankYouMsg);
  response.hangup();

  res.type('text/xml');
  res.send(response.toString());
});

// Helper for calling simulation engine
function simulateCallLifecycle(leadId) {
  setTimeout(async () => {
    // 1. Connection (In Conversation) after 3s
    if (isMongoConnected) {
      try {
        const lead = await Lead.findById(leadId);
        if (lead && lead.status === 'Calling...') {
          await Lead.findByIdAndUpdate(leadId, { $set: { status: 'In Conversation' } });
          console.log(`[SIMULATOR-MONGO] Connected to ${lead.name}. Synthesized speech running.`);
        }
      } catch (_) {}
    } else {
      const leads = readJsonFile(LEADS_FILE);
      const idx = leads.findIndex(l => l.id === leadId);
      if (idx !== -1 && leads[idx].status === 'Calling...') {
        leads[idx].status = 'In Conversation';
        writeJsonFile(LEADS_FILE, leads);
        console.log(`[SIMULATOR-FILE] Connected to ${leads[idx].name}. Synthesized speech running.`);
      }
    }

    // 2. Playback speech & client inputs digit after 5s
    setTimeout(async () => {
      let leadName = 'Lead';
      const randomResponse = Math.random();
      let outcome = 'Interested';
      let notes = 'Simulated call: Client clicked "1 - Interested" in response to Llama pitch';
      
      if (randomResponse < 0.45) {
        outcome = 'Interested';
        notes = 'Simulated: Client selected 1 - Request mockup!';
      } else if (randomResponse < 0.75) {
        outcome = 'Callback Later';
        notes = 'Simulated: Client selected 2 - Traveling, callback tomorrow';
      } else {
        outcome = 'Rejected';
        notes = 'Simulated: Client selected 3 - Declined web development';
      }

      if (isMongoConnected) {
        try {
          const lObj = await Lead.findById(leadId);
          if (lObj && lObj.status === 'In Conversation') {
            await Lead.findByIdAndUpdate(leadId, {
              $set: { status: outcome, notes: notes }
            });
            leadName = lObj.name;
          }
        } catch (_) {}
      } else {
        const leads = readJsonFile(LEADS_FILE);
        const idx = leads.findIndex(l => l.id === leadId);
        if (idx !== -1 && leads[idx].status === 'In Conversation') {
          leads[idx].status = outcome;
          leads[idx].notes = notes;
          writeJsonFile(LEADS_FILE, leads);
          leadName = leads[idx].name;
        }
      }

      console.log(`[SIMULATOR] Call finalized for ${leadName}. Result: ${outcome}`);

    }, 5000);

  }, 3000);
}


// Start Server
app.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`  WEBGENIXX AI CALLER BACKEND INITIATED ON PORT ${PORT} `);
  console.log(`=======================================================`);
  console.log(`Server URL: http://localhost:${PORT}`);
  console.log(`Resilient DB Connections: MongoDB + Fallback File Caching`);
  console.log(`Use ngrok to expose locally: ngrok http ${PORT}`);
  console.log(`Pre-seeded Admin User: founder@webgenixx.com / webgenixx123`);
  console.log(`=======================================================`);
});
