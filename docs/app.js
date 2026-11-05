const db = supabase.createClient(CONFIG.url, CONFIG.key);
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const note = t => { const n = $('#toast'); n.textContent = t; n.hidden = false; setTimeout(() => (n.hidden = true), 4000); };
let me = null, mode = 'in', ctxEmail = '', posts = [], more = true;
const LOGO = '<img src="logo.svg" alt="" width="32" height="32"><b>Kin</b>';
const HEART = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 21s-8-5.3-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.7-8 11-8 11z"/></svg>';

function renderAuth(m = '') {
  const t = { in: 'Sign in', up: 'Create account', code: 'Confirm email', reset: 'Set new password' }[mode];
  $('#app').innerHTML = `<form class="auth" id="af"><div class="brand">${LOGO}</div>
    ${mode === 'up' ? '<label for="u">Username</label><input id="u" name="user" type="text" autocomplete="username" required>' : ''}
    <label for="e">Email</label><input id="e" name="email" type="email" autocomplete="email" value="${esc(ctxEmail)}" required>
    ${mode === 'code' || mode === 'reset' ? '<label for="c">Code from email</label><input id="c" name="code" type="text" inputmode="numeric" autocomplete="one-time-code" required>' : ''}
    ${mode !== 'code' ? `<label for="p">${mode === 'reset' ? 'New password' : 'Password'}</label><input id="p" name="pass" type="password" minlength="6" autocomplete="${mode === 'in' ? 'current-password' : 'new-password'}" required>` : ''}
    <p id="msg" role="alert">${esc(m)}</p>
    <button class="btn" type="submit">${t}</button>
    <div>${mode === 'in' || mode === 'up' ? `<button class="link" type="button" id="sw">${mode === 'in' ? 'Create an account' : 'I already have an account'}</button>` : '<button class="link" type="button" id="sw">Back to sign in</button>'}
    ${mode === 'in' ? '<br><button class="link" type="button" id="fg">Forgot password</button>' : ''}</div></form>`;
  $('#af').onsubmit = submitAuth;
  $('#sw').onclick = () => { mode = mode === 'in' ? 'up' : 'in'; ctxEmail = $('#e').value; renderAuth(); };
  if ($('#fg')) $('#fg').onclick = async () => {
    const e = $('#e').value.trim();
    if (!e) return ($('#msg').textContent = 'Enter your email first.');
    const { error } = await db.auth.resetPasswordForEmail(e);
    if (error) return ($('#msg').textContent = error.message);
    ctxEmail = e; mode = 'reset'; renderAuth('If that email exists, a code was sent.');
  };
}

async function submitAuth(ev) {
  ev.preventDefault();
  const f = new FormData(ev.target), em = (f.get('email') || '').trim(), pw = f.get('pass'), code = (f.get('code') || '').trim(), un = (f.get('user') || '').trim().toLowerCase();
  const fail = e => ($('#msg').textContent = e.message || 'Request failed. Check your connection.');
  ctxEmail = em;
  try {
    if (mode === 'up') {
      if (!/^[a-z0-9_]{3,20}$/.test(un)) return fail({ message: 'Username: 3 to 20 letters, numbers or underscores.' });
      const { data, error } = await db.auth.signUp({ email: em, password: pw, options: { data: { username: un } } });
      if (error) return fail(error);
      if (!data.session) { mode = 'code'; renderAuth('Enter the code we emailed you.'); }
    } else if (mode === 'code') {
      const { error } = await db.auth.verifyOtp({ email: em, token: code, type: 'signup' });
      if (error) fail(error);
    } else if (mode === 'reset') {
      let r = await db.auth.verifyOtp({ email: em, token: code, type: 'recovery' });
      if (r.error) return fail(r.error);
      r = await db.auth.updateUser({ password: pw });
      if (r.error) fail(r.error);
    } else {
      const { error } = await db.auth.signInWithPassword({ email: em, password: pw });
      if (error) fail(error);
    }
  } catch (e) { fail(e); }
}

function shell() {
  $('#app').innerHTML = `<header class="bar"><div class="brand">${LOGO}</div><nav><button data-t="home">Home</button><button data-t="search">Search</button><button id="out">Sign out</button></nav></header><main id="view"></main>`;
  document.querySelectorAll('nav [data-t]').forEach(b => (b.onclick = () => show(b.dataset.t)));
  $('#out').onclick = () => db.auth.signOut();
  show('home');
}
function show(t) {
  document.querySelectorAll('nav [data-t]').forEach(b => b.setAttribute('aria-current', b.dataset.t === t));
  t === 'home' ? home() : searchView();
}

function home() {
  $('#view').innerHTML = `<form class="card" id="pf"><label for="b" class="meta" style="margin-top:0">New post</label><textarea id="b" rows="3" maxlength="500" placeholder="What is on your mind?"></textarea>
    <div class="row" style="margin-top:8px"><input id="img" type="file" accept="image/jpeg,image/png,image/webp" aria-label="Add image"><button class="btn" type="submit">Post</button></div></form>
    <div id="list"></div><button class="btn ghost" id="more" hidden>Load more</button>`;
  $('#pf').onsubmit = createPost;
  $('#more').onclick = () => loadFeed(false);
  $('#list').onclick = ev => {
    const b = ev.target.closest('[data-a]'); if (!b) return;
    b.dataset.a === 'like' ? like(b.dataset.id) : removePost(b.dataset.id);
  };
  loadFeed(true);
}

async function loadFeed(reset) {
  if (reset) { posts = []; more = true; }
  try {
    const f = await db.from('follows').select('followee_id').eq('follower_id', me.id);
    if (f.error) throw f.error;
    const ids = [me.id, ...f.data.map(r => r.followee_id)];
    const r = await db.from('posts').select('*, profiles(username), likes(user_id)').in('user_id', ids).order('created_at', { ascending: false }).range(posts.length, posts.length + 19);
    if (r.error) throw r.error;
    posts = posts.concat(r.data); more = r.data.length === 20; draw();
  } catch (e) { $('#list').textContent = 'Could not load posts.'; }
}

function draw() {
  $('#list').innerHTML = posts.length ? posts.map(card).join('') : '<p class="empty">Your feed is empty. Find people in Search, or write your first post.</p>';
  $('#more').hidden = !more || !posts.length;
}

function card(p) {
  const liked = p.likes.some(l => l.user_id === me.id), d = new Date(p.created_at).toLocaleString();
  return `<article class="card"><div class="row"><b>@${esc(p.profiles.username)}</b><span class="meta">${esc(d)}</span></div>
    ${p.body ? `<p>${esc(p.body)}</p>` : ''}${p.media_url ? `<img class="m" src="${esc(p.media_url)}" alt="Post image" loading="lazy">` : ''}
    <div style="margin-top:8px"><button class="act ${liked ? 'on' : ''}" data-a="like" data-id="${p.id}" aria-label="${liked ? 'Unlike' : 'Like'}">${HEART}${p.likes.length}</button>
    ${p.user_id === me.id ? `<button class="act" data-a="del" data-id="${p.id}">Delete</button>` : ''}</div></article>`;
}

async function like(id) {
  const p = posts.find(x => x.id === id), was = p.likes.some(l => l.user_id === me.id);
  const r = was ? await db.from('likes').delete().match({ post_id: id, user_id: me.id }) : await db.from('likes').insert({ post_id: id });
  if (r.error) return note(r.error.message);
  p.likes = was ? p.likes.filter(l => l.user_id !== me.id) : [...p.likes, { user_id: me.id }]; draw();
}

async function removePost(id) {
  const r = await db.from('posts').delete().eq('id', id);
  if (r.error) return note(r.error.message);
  posts = posts.filter(p => p.id !== id); draw();
}

async function createPost(ev) {
  ev.preventDefault();
  const body = $('#b').value.trim(), file = $('#img').files[0];
  if (!body && !file) return;
  if (file && file.size > 25 * 1024 * 1024) return note('Image must be under 25 MB.');
  try {
    let url = null;
    if (file) {
      const ext = file.type.split('/')[1].replace('jpeg', 'jpg'), path = `${me.id}/${Date.now()}.${ext}`;
      const up = await db.storage.from('media').upload(path, file, { contentType: file.type });
      if (up.error) throw up.error;
      url = db.storage.from('media').getPublicUrl(path).data.publicUrl;
    }
    const r = await db.from('posts').insert({ body, media_url: url });
    if (r.error) throw r.error;
    ev.target.reset(); loadFeed(true);
  } catch (e) { note(e.message || 'Post failed.'); }
}

function searchView() {
  $('#view').innerHTML = `<form class="card" id="sf"><label for="q" class="meta" style="margin-top:0">Search usernames</label><div class="row"><input id="q" type="text" required><button class="btn" type="submit">Search</button></div></form><div id="res"></div>`;
  $('#sf').onsubmit = async ev => {
    ev.preventDefault();
    const q = $('#q').value.trim().toLowerCase().replace(/[^a-z0-9_]/g, ''); if (!q) return;
    const [u, f] = await Promise.all([db.from('profiles').select('id, username, bio').ilike('username', `%${q}%`).neq('id', me.id).limit(20), db.from('follows').select('followee_id').eq('follower_id', me.id)]);
    if (u.error || f.error) return note('Search failed.');
    const set = new Set(f.data.map(r => r.followee_id));
    $('#res').innerHTML = u.data.length ? u.data.map(x => `<div class="card row"><div><b>@${esc(x.username)}</b><div class="meta">${esc(x.bio)}</div></div><button class="btn ${set.has(x.id) ? 'ghost' : ''}" data-id="${x.id}" data-f="${set.has(x.id)}">${set.has(x.id) ? 'Unfollow' : 'Follow'}</button></div>`).join('') : '<p class="empty">No users found.</p>';
  };
  $('#res').onclick = async ev => {
    const b = ev.target.closest('[data-id]'); if (!b) return;
    const was = b.dataset.f === 'true';
    const r = was ? await db.from('follows').delete().match({ follower_id: me.id, followee_id: b.dataset.id }) : await db.from('follows').insert({ followee_id: b.dataset.id });
    if (r.error) return note(r.error.message);
    b.dataset.f = String(!was); b.textContent = was ? 'Follow' : 'Unfollow'; b.classList.toggle('ghost', !was);
  };
}

db.auth.onAuthStateChange((_e, s) => {
  me = s ? s.user : null;
  me ? shell() : renderAuth();
});
db.auth.getSession().then(({ data }) => { if (!data.session) renderAuth(); });
