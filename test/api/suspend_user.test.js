const assert = require('node:assert/strict');
const path = require('node:path');
const { test, beforeEach } = require('node:test');

const SERVER_TIME = Symbol('serverTime');
const DELETE_FIELD = Symbol('deleteField');
let store;
let authUpdates;

function writeDoc(key, data) {
  const next = { ...(store.get(key) || {}) };
  for (const [field, value] of Object.entries(data)) {
    if (value === DELETE_FIELD) delete next[field];
    else next[field] = value === SERVER_TIME ? new Date() : value;
  }
  store.set(key, next);
}

function docRef(collection, id) {
  const key = `${collection}/${id}`;
  return {
    id,
    key,
    path: key,
    async get() {
      const data = store.get(key);
      return {
        exists: data !== undefined,
        data: () => (data ? { ...data } : undefined),
      };
    },
    async update(data) { writeDoc(key, data); },
  };
}

const firestore = {
  collection(name) {
    return {
      doc: (id) => docRef(name, id),
      where() {
        return { get: async () => ({ docs: [] }) };
      },
    };
  },
  batch() {
    return { update() {}, async commit() {} };
  },
};

const fakeAdmin = {
  firestore: Object.assign(() => firestore, {
    FieldValue: {
      serverTimestamp: () => SERVER_TIME,
      delete: () => DELETE_FIELD,
    },
  }),
  auth: () => ({
    async updateUser(uid, changes) { authUpdates.push({ uid, changes }); },
    async revokeRefreshTokens() {},
  }),
};

function stub(modulePath, exports) {
  const resolved = require.resolve(path.join(__dirname, '../../', modulePath));
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports,
  };
}

stub('server/auth.js', {
  getFirebaseAdmin: () => fakeAdmin,
  requireUser: async () => ({
    uid: 'admin-1',
    email: 'admin@example.com',
    email_verified: true,
  }),
});

const suspendUser = require('../../api/suspend-user');

function call(body) {
  return new Promise((resolve) => {
    const res = {
      statusCode: 200,
      setHeader() {},
      status(code) { this.statusCode = code; return this; },
      json(payload) {
        resolve({ status: this.statusCode, body: payload });
        return this;
      },
      end() { resolve({ status: this.statusCode }); return this; },
    };
    suspendUser({ method: 'POST', headers: {}, body }, res);
  });
}

beforeEach(() => {
  store = new Map([
    ['users/admin-1', { role: 'admin', email: 'admin@example.com' }],
    ['users/dual-role-1', {
      role: 'buyer',
      roles: ['buyer', 'creator'],
      email: 'creator@example.com',
      creatorModerationLevel: 0,
    }],
    ['creator_profiles/dual-role-1', { isStorefrontVisible: true }],
  ]);
  authUpdates = [];
});

test('first warning works when creator is currently using the buyer role', async () => {
  const response = await call({
    uid: 'dual-role-1',
    level: 1,
    reason: 'Update the prohibited listing within 24 hours.',
  });

  assert.equal(response.status, 200);
  assert.equal(response.body.level, 1);
  assert.equal(store.get('users/dual-role-1').creatorModerationLevel, 1);
  assert.equal(
    store.get('users/dual-role-1').creatorModerationReason,
    'Update the prohibited listing within 24 hours.',
  );
  assert.equal(store.get('creator_profiles/dual-role-1').moderationLevel, 1);
  assert.equal(store.get('creator_profiles/dual-role-1').isStorefrontVisible, true);
  assert.deepEqual(authUpdates, [
    { uid: 'dual-role-1', changes: { disabled: false } },
  ]);
});
