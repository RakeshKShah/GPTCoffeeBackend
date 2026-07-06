import cors from 'cors';
import express from 'express';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(__dirname, 'data');
const dataPath = path.join(dataDir, 'db.json');
const port = Number(process.env.PORT || 4100);

const gradients = [
  'from-amber-300 via-orange-500 to-stone-900',
  'from-stone-700 via-amber-800 to-black',
  'from-yellow-200 via-amber-500 to-stone-950',
  'from-orange-300 via-red-700 to-stone-950',
  'from-rose-200 via-orange-600 to-stone-950',
];

const now = new Date();
const lastMonth = new Date(now);
lastMonth.setMonth(lastMonth.getMonth() - 1);

const seedData = {
  users: [
    {
      id: 'buyer-sample',
      name: 'Maya Buyer',
      email: 'buyer@gptcoffee.test',
      password: 'buyer123',
      role: 'buyer',
    },
    {
      id: 'admin-sample',
      name: 'Ari Admin',
      email: 'admin@gptcoffee.test',
      password: 'admin123',
      role: 'admin',
    },
  ],
  products: [
    {
      id: 'velvet-latte',
      name: 'Velvet Latte',
      note: 'Caramel, oat cream, dark espresso',
      description: 'Silky steamed milk folded into a double ristretto with a toasted caramel finish.',
      price: 6.75,
      strength: 'Mellow',
      gradient: gradients[0],
    },
    {
      id: 'midnight-mocha',
      name: 'Midnight Mocha',
      note: 'Cacao, smoked vanilla, sea salt',
      description: 'A plush mocha built with single-origin cocoa and a bright espresso backbone.',
      price: 7.25,
      strength: 'Bold',
      gradient: gradients[1],
    },
    {
      id: 'golden-cortado',
      name: 'Golden Cortado',
      note: 'Brown sugar, cinnamon, microfoam',
      description: 'Equal parts espresso and textured milk, balanced with warm spice and brown sugar.',
      price: 5.95,
      strength: 'Balanced',
      gradient: gradients[2],
    },
    {
      id: 'ember-cold-brew',
      name: 'Ember Cold Brew',
      note: 'Maple, orange peel, slow steeped',
      description: 'Low-acid cold brew poured over crystal ice with a maple citrus lift.',
      price: 6.5,
      strength: 'Smooth',
      gradient: gradients[3],
    },
  ],
  customizations: {
    sizes: [
      { id: 'small', label: 'Small', price: 0 },
      { id: 'classic', label: 'Classic', price: 0.75 },
      { id: 'grand', label: 'Grand', price: 1.4 },
    ],
    milks: [
      { id: 'whole', label: 'Whole', price: 0 },
      { id: 'oat', label: 'Oat', price: 0.85 },
      { id: 'almond', label: 'Almond', price: 0.75 },
      { id: 'coconut', label: 'Coconut', price: 0.9 },
    ],
    extras: [
      { id: 'vanilla-cloud', label: 'Vanilla Cloud', price: 0.75 },
      { id: 'caramel-lace', label: 'Caramel Lace', price: 0.8 },
      { id: 'extra-shot', label: 'Extra Shot', price: 1.25 },
      { id: 'cocoa-dust', label: 'Cocoa Dust', price: 0.55 },
    ],
  },
  orders: [
    {
      id: 'ORD-1001',
      buyerId: 'buyer-sample',
      buyerName: 'Maya Buyer',
      createdAt: now.toISOString(),
      readyAt: new Date(now.getTime() + 15 * 60 * 1000).toISOString(),
      status: 'Ready for pickup',
      total: 18.55,
      items: [
        {
          id: 'item-1001',
          productName: 'Midnight Mocha',
          size: 'Grand',
          milk: 'Oat',
          extras: ['Extra Shot', 'Cocoa Dust'],
          quantity: 2,
          total: 18.55,
        },
      ],
    },
    {
      id: 'ORD-1000',
      buyerId: 'buyer-sample',
      buyerName: 'Maya Buyer',
      createdAt: lastMonth.toISOString(),
      readyAt: new Date(lastMonth.getTime() + 12 * 60 * 1000).toISOString(),
      status: 'Completed',
      total: 12.45,
      items: [
        {
          id: 'item-1000',
          productName: 'Velvet Latte',
          size: 'Classic',
          milk: 'Almond',
          extras: ['Caramel Lace'],
          quantity: 1,
          total: 12.45,
        },
      ],
    },
  ],
};

async function readDb() {
  try {
    const contents = await readFile(dataPath, 'utf8');
    return JSON.parse(contents);
  } catch {
    await writeDb(seedData);
    return structuredClone(seedData);
  }
}

async function writeDb(data) {
  await mkdir(dataDir, { recursive: true });
  await writeFile(dataPath, JSON.stringify(data, null, 2));
}

function publicUser(user) {
  const { password: _password, ...rest } = user;
  return rest;
}

function makeToken(user) {
  return Buffer.from(JSON.stringify({ userId: user.id, role: user.role })).toString('base64url');
}

async function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';

  try {
    const payload = JSON.parse(Buffer.from(token, 'base64url').toString('utf8'));
    const db = await readDb();
    const user = db.users.find((candidate) => candidate.id === payload.userId);
    if (!user) return res.status(401).json({ message: 'Invalid session.' });
    req.user = user;
    req.db = db;
    next();
  } catch {
    res.status(401).json({ message: 'Missing or invalid session.' });
  }
}

function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ message: 'Admin access required.' });
  }
  next();
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

const app = express();
app.use(cors({ origin: process.env.CLIENT_ORIGIN || true }));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const db = await readDb();
  const user = db.users.find(
    (candidate) => candidate.email.toLowerCase() === String(email || '').toLowerCase() && candidate.password === password,
  );

  if (!user) {
    return res.status(401).json({ message: 'No user found with that email and password.' });
  }

  res.json({ token: makeToken(user), user: publicUser(user) });
});

app.post('/api/auth/signup', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password || String(password).length < 6) {
    return res.status(400).json({ message: 'Name, email, and a 6+ character password are required.' });
  }

  const db = await readDb();
  if (db.users.some((user) => user.email.toLowerCase() === String(email).toLowerCase())) {
    return res.status(409).json({ message: 'That email is already registered.' });
  }

  const user = {
    id: `buyer-${Date.now()}`,
    name,
    email,
    password,
    role: 'buyer',
  };
  db.users.push(user);
  await writeDb(db);

  res.status(201).json({ token: makeToken(user), user: publicUser(user) });
});

app.get('/api/menu', async (_req, res) => {
  const db = await readDb();
  res.json({ products: db.products, customizations: db.customizations });
});

app.get('/api/orders/my', auth, (req, res) => {
  const orders = req.db.orders.filter((order) => order.buyerId === req.user.id);
  res.json({ orders });
});

app.post('/api/orders', auth, async (req, res) => {
  const { items } = req.body;
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ message: 'Order must include at least one item.' });
  }

  const db = req.db;
  const total = items.reduce((sum, item) => sum + Number(item.total || 0), 0);
  const createdAt = new Date();
  const readyAt = new Date(createdAt.getTime() + 15 * 60 * 1000);
  const order = {
    id: `ORD-${Date.now().toString().slice(-6)}`,
    buyerId: req.user.id,
    buyerName: req.user.name,
    createdAt: createdAt.toISOString(),
    readyAt: readyAt.toISOString(),
    status: 'Placed',
    total,
    items,
  };

  db.orders.unshift(order);
  await writeDb(db);
  res.status(201).json({ order });
});

app.get('/api/admin/orders', auth, requireAdmin, (req, res) => {
  res.json({ orders: req.db.orders });
});

app.patch('/api/admin/orders/:id/status', auth, requireAdmin, async (req, res) => {
  const order = req.db.orders.find((candidate) => candidate.id === req.params.id);
  if (!order) return res.status(404).json({ message: 'Order not found.' });

  order.status = req.body.status || order.status;
  await writeDb(req.db);
  res.json({ order });
});

app.post('/api/admin/products', auth, requireAdmin, async (req, res) => {
  const product = {
    id: req.body.id || slugify(req.body.name) || `coffee-${Date.now()}`,
    name: req.body.name,
    note: req.body.note || '',
    description: req.body.description || '',
    price: Number(req.body.price || 0),
    strength: req.body.strength || 'Balanced',
    gradient: req.body.gradient || gradients[req.db.products.length % gradients.length],
  };

  req.db.products.unshift(product);
  await writeDb(req.db);
  res.status(201).json({ product });
});

app.patch('/api/admin/products/:id', auth, requireAdmin, async (req, res) => {
  const index = req.db.products.findIndex((product) => product.id === req.params.id);
  if (index === -1) return res.status(404).json({ message: 'Product not found.' });

  req.db.products[index] = {
    ...req.db.products[index],
    ...req.body,
    id: req.params.id,
    price: Number(req.body.price ?? req.db.products[index].price),
  };
  await writeDb(req.db);
  res.json({ product: req.db.products[index] });
});

app.delete('/api/admin/products/:id', auth, requireAdmin, async (req, res) => {
  req.db.products = req.db.products.filter((product) => product.id !== req.params.id);
  await writeDb(req.db);
  res.status(204).send();
});

app.put('/api/admin/customizations', auth, requireAdmin, async (req, res) => {
  req.db.customizations = req.body.customizations;
  await writeDb(req.db);
  res.json({ customizations: req.db.customizations });
});

app.get('/api/admin/sales', auth, requireAdmin, (req, res) => {
  const today = new Date().toDateString();
  const month = `${new Date().getFullYear()}-${new Date().getMonth()}`;
  const daily = req.db.orders
    .filter((order) => new Date(order.createdAt).toDateString() === today)
    .reduce((sum, order) => sum + order.total, 0);
  const monthly = req.db.orders
    .filter((order) => `${new Date(order.createdAt).getFullYear()}-${new Date(order.createdAt).getMonth()}` === month)
    .reduce((sum, order) => sum + order.total, 0);
  const total = req.db.orders.reduce((sum, order) => sum + order.total, 0);

  res.json({ daily, monthly, total, orderCount: req.db.orders.length });
});

app.listen(port, () => {
  console.log(`GPT Coffee API running on http://localhost:${port}`);
});
