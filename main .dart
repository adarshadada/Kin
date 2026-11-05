import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kUrl = 'https://gkpjicnihgicrsndjltl.supabase.co';
const kKey = 'sb_publishable_cx1YkMueniFpjQJTk-J7AQ_64LGWzos';
const teal = Color(0xFF0E7C66);

SupabaseClient get db => Supabase.instance.client;
String get me => db.auth.currentUser!.id;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kUrl, anonKey: kKey);
  runApp(const KinApp());
}

String errText(Object e) {
  if (e is String) return e;
  if (e is AuthException) return e.message.contains('Database error') ? 'That username is taken or invalid. Try another.' : e.message;
  if (e is PostgrestException) return e.message;
  return 'Request failed. Check your connection.';
}

void toast(BuildContext c, Object e) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(errText(e))));
}

String stamp(String s) {
  final d = DateTime.parse(s).toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
}

class KinLogo extends StatelessWidget {
  final double size;
  const KinLogo({super.key, this.size = 40});
  @override
  Widget build(BuildContext c) => SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter()));
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 32;
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(8 * u)), Paint()..color = teal);
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
        Path()
          ..moveTo(10 * u, 7 * u)
          ..lineTo(10 * u, 25 * u)
          ..moveTo(10 * u, 16 * u)
          ..lineTo(21 * u, 7 * u)
          ..moveTo(14 * u, 13 * u)
          ..lineTo(22 * u, 25 * u),
        p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class Avatar extends StatelessWidget {
  final String name;
  final double r;
  const Avatar(this.name, {super.key, this.r = 18});
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return CircleAvatar(
        radius: r,
        backgroundColor: cs.primaryContainer,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: r * 0.9)));
  }
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: Theme.of(c).colorScheme.outline),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
      ]));
}

class Reveal extends StatelessWidget {
  final Widget child;
  const Reveal({super.key, required this.child});
  @override
  Widget build(BuildContext c) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (_, v, w) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: w)),
      child: child);
}

class KinApp extends StatelessWidget {
  const KinApp({super.key});
  ThemeData _t(Brightness b) {
    final dark = b == Brightness.dark;
    final cs = ColorScheme.fromSeed(seedColor: teal, brightness: b);
    final line = dark ? const Color(0xFF26302C) : const Color(0xFFE2E5E0);
    final bg = dark ? const Color(0xFF0F1412) : const Color(0xFFF6F7F4);
    final surface = dark ? const Color(0xFF171E1B) : Colors.white;
    final r = BorderRadius.circular(8);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: line))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: line)), enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: line))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: r))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), side: BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: r))),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, indicatorColor: cs.primaryContainer),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: surface, indicatorColor: cs.primaryContainer),
      dividerColor: line,
    );
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Kin',
        debugShowCheckedModeBanner: false,
        theme: _t(Brightness.light),
        darkTheme: _t(Brightness.dark),
        home: StreamBuilder<AuthState>(stream: db.auth.onAuthStateChange, builder: (c, _) => db.auth.currentSession == null ? const AuthPage() : const Shell()),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthState();
}

class _AuthState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController(), user = TextEditingController(), code = TextEditingController();
  int mode = 0; // 0 sign in, 1 sign up, 2 confirm email code, 3 reset password code
  bool busy = false, show = false;
  static const titles = ['Welcome back', 'Create your account', 'Check your email', 'Choose a new password'];
  static const labels = ['Sign in', 'Create account', 'Confirm email', 'Set password'];

  Future<void> _run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (x) {
      if (mounted) toast(context, x);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _go() => _run(() async {
        final e = email.text.trim(), u = user.text.trim().toLowerCase(), t = code.text.trim();
        if (e.isEmpty) return toast(context, 'Enter your email.');
        if (mode == 1) {
          if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) return toast(context, 'Username: 3 to 20 letters, numbers or underscores.');
          await db.auth.signUp(email: e, password: pass.text, data: {'username': u});
          if (db.auth.currentSession == null && mounted) {
            setState(() => mode = 2);
            toast(context, 'Enter the code we emailed you.');
          }
        } else if (mode == 2) {
          await db.auth.verifyOTP(email: e, token: t, type: OtpType.signup);
        } else if (mode == 3) {
          await db.auth.verifyOTP(email: e, token: t, type: OtpType.recovery);
          await db.auth.updateUser(UserAttributes(password: pass.text));
        } else {
          await db.auth.signInWithPassword(email: e, password: pass.text);
        }
      });

  Future<void> _forgot() => _run(() async {
        if (email.text.trim().isEmpty) return toast(context, 'Enter your email first.');
        await db.auth.resetPasswordForEmail(email.text.trim());
        if (mounted) {
          setState(() => mode = 3);
          toast(context, 'If that email exists, a code was sent.');
        }
      });

  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.7, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (_, v, w) => Align(alignment: Alignment.centerLeft, child: Transform.scale(scale: v, alignment: Alignment.centerLeft, child: w)),
                  child: const KinLogo(size: 64)),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(titles[mode], key: ValueKey(mode), style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(height: 4),
              Text('Posts and photos from people you follow.', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 20),
              AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: Column(children: [
                    if (mode == 1) ...[TextField(controller: user, autocorrect: false, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email))), const SizedBox(height: 12)],
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
                    const SizedBox(height: 12),
                    if (mode >= 2) ...[TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Code from email', prefixIcon: Icon(Icons.pin_outlined))), const SizedBox(height: 12)],
                    if (mode != 2) ...[
                      TextField(
                          controller: pass,
                          obscureText: !show,
                          decoration: InputDecoration(
                              labelText: mode == 3 ? 'New password' : 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(tooltip: show ? 'Hide password' : 'Show password', onPressed: () => setState(() => show = !show), icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
                      const SizedBox(height: 16)
                    ],
                  ])),
              FilledButton(
                  onPressed: busy ? null : _go,
                  child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(labels[mode])),
              const SizedBox(height: 4),
              if (mode < 2) TextButton(onPressed: () => setState(() => mode = 1 - mode), child: Text(mode == 1 ? 'I already have an account' : 'Create an account')),
              if (mode == 0) TextButton(onPressed: busy ? null : _forgot, child: const Text('Forgot password')),
              if (mode >= 2) TextButton(onPressed: () => setState(() => mode = 0), child: const Text('Back to sign in')),
            ]),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0, rev = 0;
  static const _d = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.search, Icons.search, 'Search'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Messages'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.of(c).size.width >= 700;
    final pages = [Feed(key: ValueKey(rev)), const SearchPage(), const Inbox(), ProfilePage(userId: me, embedded: true)];
    final body = Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey('$i-$rev'), child: pages[i]))));
    return Scaffold(
      appBar: AppBar(title: Row(children: [const KinLogo(size: 28), const SizedBox(width: 10), Text(_d[i].$3, style: const TextStyle(fontWeight: FontWeight.w700))])),
      floatingActionButton: i == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const Compose())) == true) setState(() => rev++);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Post'))
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => setState(() => i = v),
              destinations: [for (final d in _d) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)]),
      body: wide
          ? Row(children: [
              NavigationRail(
                  selectedIndex: i,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (v) => setState(() => i = v),
                  destinations: [for (final d in _d) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))]),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
    );
  }
}

class Feed extends StatefulWidget {
  final String? userId;
  final Widget? header;
  const Feed({super.key, this.userId, this.header});
  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true, more = true;
  String? err;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool reset = false}) async {
    if (reset) {
      posts = [];
      more = true;
    }
    setState(() {
      loading = true;
      err = null;
    });
    try {
      List<String> ids;
      if (widget.userId != null) {
        ids = [widget.userId!];
      } else {
        final f = await db.from('follows').select('followee_id').eq('follower_id', me);
        ids = [me, ...f.map((r) => r['followee_id'] as String)];
      }
      final r = await db.from('posts').select('*, profiles(username), likes(user_id), comments(count)').inFilter('user_id', ids).order('created_at', ascending: false).range(posts.length, posts.length + 19);
      posts = [...posts, ...r];
      more = r.length == 20;
    } catch (_) {
      err = 'Could not load posts. Pull down to retry.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => RefreshIndicator(
        onRefresh: () => load(reset: true),
        child: ListView(padding: const EdgeInsets.all(12), physics: const AlwaysScrollableScrollPhysics(), children: [
          if (widget.header != null) widget.header!,
          for (final p in posts) Reveal(key: ValueKey(p['id']), child: PostCard(p: p, onGone: () => setState(() => posts.remove(p)))),
          if (err != null) Empty(Icons.cloud_off, err!),
          if (loading && posts.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (!loading && posts.isEmpty && err == null) Empty(Icons.dynamic_feed_outlined, widget.userId == null ? 'Your feed is empty.\nFind people in Search, or write your first post.' : 'No posts yet.'),
          if (!loading && more && posts.isNotEmpty) TextButton(onPressed: load, child: const Text('Load more')),
        ]),
      );
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> p;
  final VoidCallback onGone;
  const PostCard({super.key, required this.p, required this.onGone});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  Map<String, dynamic> get p => widget.p;
  late bool liked = (p['likes'] as List).any((l) => l['user_id'] == me);
  late int n = (p['likes'] as List).length;

  Future<void> like() async {
    final was = liked;
    setState(() {
      liked = !was;
      n += was ? -1 : 1;
    });
    try {
      if (was) {
        await db.from('likes').delete().match({'post_id': p['id'], 'user_id': me});
      } else {
        await db.from('likes').insert({'post_id': p['id']});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        liked = was;
        n += was ? 1 : -1;
      });
      toast(context, e);
    }
  }

  Future<void> menu(String v) async {
    try {
      if (v == 'delete') {
        await db.from('posts').delete().eq('id', p['id']);
        widget.onGone();
      } else {
        await db.from('reports').insert({'post_id': p['id'], 'reason': 'reported by user'});
        if (mounted) toast(context, 'Report sent.');
      }
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final own = p['user_id'] == me, name = p['profiles']['username'] as String;
    final cc = (p['comments'] as List).isEmpty ? 0 : p['comments'][0]['count'];
    final cs = Theme.of(c).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(userId: p['user_id']))),
                child: Row(children: [Avatar(name), const SizedBox(width: 10), Text('@$name', style: const TextStyle(fontWeight: FontWeight.w600))])),
            const Spacer(),
            Text(stamp(p['created_at']), style: Theme.of(c).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            PopupMenuButton<String>(onSelected: menu, itemBuilder: (_) => [PopupMenuItem(value: own ? 'delete' : 'report', child: Text(own ? 'Delete' : 'Report'))]),
          ]),
          if ((p['body'] as String).isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8, top: 4, bottom: 6), child: Text(p['body'], style: const TextStyle(fontSize: 16, height: 1.4))),
          if (p['media_url'] != null)
            Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(p['media_url'], fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(16), child: Text('Image unavailable'))))),
          Row(children: [
            IconButton(
                tooltip: liked ? 'Unlike' : 'Like',
                onPressed: like,
                icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                    child: Icon(liked ? Icons.favorite : Icons.favorite_border, key: ValueKey(liked), color: liked ? Colors.red.shade700 : null))),
            Text('$n'),
            const SizedBox(width: 8),
            IconButton(tooltip: 'Comments', onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CommentsPage(postId: p['id']))), icon: const Icon(Icons.mode_comment_outlined)),
            Text('$cc'),
          ]),
        ]),
      ),
    );
  }
}

class Compose extends StatefulWidget {
  const Compose({super.key});
  @override
  State<Compose> createState() => _ComposeState();
}

class _ComposeState extends State<Compose> {
  final text = TextEditingController();
  Uint8List? img;
  String ext = 'jpg';
  bool busy = false;

  Future<void> pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    final b = await x.readAsBytes(), e = x.name.split('.').last.toLowerCase();
    if (!mounted) return;
    if (b.length > 25 * 1024 * 1024) return toast(context, 'Image must be under 25 MB.');
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(e)) return toast(context, 'Use a JPG, PNG or WebP image.');
    setState(() {
      img = b;
      ext = e == 'jpeg' ? 'jpg' : e;
    });
  }

  Future<void> post() async {
    final t = text.text.trim();
    if (t.isEmpty && img == null) return;
    setState(() => busy = true);
    try {
      String? url;
      if (img != null) {
        final path = '$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await db.storage.from('media').uploadBinary(path, img!, fileOptions: FileOptions(contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
        url = db.storage.from('media').getPublicUrl(path);
      }
      await db.from('posts').insert({'body': t, 'media_url': url});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        toast(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('New post'), actions: [
          Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: busy ? null : post, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Post')))
        ]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextField(controller: text, maxLines: 6, maxLength: 500, autofocus: true, decoration: const InputDecoration(hintText: 'What is on your mind?')),
              AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: img == null
                      ? const SizedBox(width: double.infinity)
                      : Stack(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(img!, width: double.infinity, height: 240, fit: BoxFit.cover)),
                          Positioned(top: 4, right: 4, child: IconButton.filledTonal(tooltip: 'Remove image', onPressed: () => setState(() => img = null), icon: const Icon(Icons.close))),
                        ])),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: pick, icon: const Icon(Icons.image_outlined), label: const Text('Add image'))),
            ]),
          ),
        ),
      );
}

class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({super.key, required this.postId});
  @override
  State<CommentsPage> createState() => _CommentsState();
}

class _CommentsState extends State<CommentsPage> {
  final text = TextEditingController();
  List<Map<String, dynamic>>? rows;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await db.from('comments').select('*, profiles(username)').eq('post_id', widget.postId).order('created_at').limit(200);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) {
        toast(context, e);
        setState(() => rows = []);
      }
    }
  }

  Future<void> send() async {
    final t = text.text.trim();
    if (t.isEmpty) return;
    try {
      await db.from('comments').insert({'post_id': widget.postId, 'body': t});
      text.clear();
      load();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(children: [
              Expanded(
                  child: rows == null
                      ? const Center(child: CircularProgressIndicator())
                      : rows!.isEmpty
                          ? const Center(child: Empty(Icons.mode_comment_outlined, 'No comments yet.'))
                          : ListView(children: [
                              for (final r in rows!)
                                Reveal(
                                    key: ValueKey(r['id']),
                                    child: ListTile(
                                        leading: Avatar(r['profiles']['username']),
                                        title: Text('@${r['profiles']['username']}'),
                                        subtitle: Text(r['body']),
                                        trailing: Text(stamp(r['created_at']), style: Theme.of(c).textTheme.bodySmall)))
                            ])),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: text, maxLength: 300, decoration: const InputDecoration(hintText: 'Add a comment', counterText: ''), onSubmitted: (_) => send())),
                        const SizedBox(width: 8),
                        IconButton.filled(tooltip: 'Send', onPressed: send, icon: const Icon(Icons.send)),
                      ]))),
            ]),
          ),
        ),
      );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchState();
}

class _SearchState extends State<SearchPage> {
  List<Map<String, dynamic>>? rows;

  Future<void> run(String q) async {
    q = q.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (q.isEmpty) return;
    try {
      final r = await db.from('profiles').select('id, username, bio').ilike('username', '%$q%').neq('id', me).limit(20);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext c) => Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onSubmitted: run, textInputAction: TextInputAction.search, decoration: const InputDecoration(hintText: 'Search usernames', prefixIcon: Icon(Icons.search)))),
        Expanded(
            child: rows == null
                ? const Center(child: Empty(Icons.search, 'Search for people by username.'))
                : rows!.isEmpty
                    ? const Center(child: Empty(Icons.person_search_outlined, 'No users found.'))
                    : ListView(children: [
                        for (final r in rows!)
                          Reveal(
                              key: ValueKey(r['id']),
                              child: ListTile(
                                  leading: Avatar(r['username']),
                                  title: Text('@${r['username']}'),
                                  subtitle: Text(r['bio'], maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(userId: r['id'])))))
                      ])),
      ]);
}

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool embedded;
  const ProfilePage({super.key, required this.userId, this.embedded = false});
  @override
  State<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<ProfilePage> {
  Map<String, dynamic>? prof;
  int followers = 0, following = 0;
  bool isFollowing = false;
  bool get own => widget.userId == me;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final id = widget.userId;
      final p = await db.from('profiles').select().eq('id', id).single();
      final a = await db.from('follows').select('follower_id').eq('followee_id', id);
      final b = await db.from('follows').select('followee_id').eq('follower_id', id);
      if (mounted) {
        setState(() {
          prof = p;
          followers = a.length;
          following = b.length;
          isFollowing = a.any((r) => r['follower_id'] == me);
        });
      }
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  Future<void> toggleFollow() async {
    try {
      if (isFollowing) {
        await db.from('follows').delete().match({'follower_id': me, 'followee_id': widget.userId});
      } else {
        await db.from('follows').insert({'followee_id': widget.userId});
      }
      load();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  Future<void> editBio() async {
    final t = TextEditingController(text: prof!['bio']);
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Edit bio'),
              content: TextField(controller: t, maxLength: 160, maxLines: 3),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
            ));
    if (ok != true) return;
    try {
      await db.from('profiles').update({'bio': t.text.trim()}).eq('id', me);
      load();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  Widget _head(BuildContext c, Map<String, dynamic> p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(p['username'], r: 30),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('@${p['username']}', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), Text('$followers followers  |  $following following', style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant))])),
            ]),
            if ((p['bio'] as String).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(p['bio'])),
            const SizedBox(height: 12),
            if (own)
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: editBio, icon: const Icon(Icons.edit_outlined), label: const Text('Edit bio')),
                OutlinedButton.icon(onPressed: db.auth.signOut, icon: const Icon(Icons.logout), label: const Text('Sign out')),
              ])
            else
              Row(children: [
                Expanded(child: FilledButton(onPressed: toggleFollow, child: Text(isFollowing ? 'Unfollow' : 'Follow'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ChatPage(otherId: widget.userId, name: p['username']))), child: const Text('Message'))),
              ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext c) {
    final p = prof;
    final body = p == null ? const Center(child: CircularProgressIndicator()) : Feed(userId: widget.userId, header: _head(c, p));
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(p == null ? '' : '@${p['username']}')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: body)));
  }
}

class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  List<Map<String, dynamic>>? rows;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final m = await db.from('messages').select('sender_id, recipient_id, body, created_at').order('created_at', ascending: false).limit(300);
      final last = <String, Map<String, dynamic>>{};
      for (final r in m) {
        last.putIfAbsent(r['sender_id'] == me ? r['recipient_id'] : r['sender_id'], () => r);
      }
      final ps = last.isEmpty ? <Map<String, dynamic>>[] : await db.from('profiles').select('id, username').inFilter('id', last.keys.toList());
      if (mounted) setState(() => rows = [for (final p in ps) {...p, 'last': last[p['id']]!['body']}]);
    } catch (e) {
      if (mounted) {
        toast(context, e);
        setState(() => rows = []);
      }
    }
  }

  @override
  Widget build(BuildContext c) => rows == null
      ? const Center(child: CircularProgressIndicator())
      : rows!.isEmpty
          ? const Center(child: Empty(Icons.chat_bubble_outline, 'No conversations yet.\nOpen a profile and tap Message.'))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(children: [
                for (final r in rows!)
                  ListTile(
                      leading: Avatar(r['username']),
                      title: Text('@${r['username']}'),
                      subtitle: Text(r['last'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        await Navigator.push(c, MaterialPageRoute(builder: (_) => ChatPage(otherId: r['id'], name: r['username'])));
                        load();
                      })
              ]));
}

class ChatPage extends StatefulWidget {
  final String otherId, name;
  const ChatPage({super.key, required this.otherId, required this.name});
  @override
  State<ChatPage> createState() => _ChatState();
}

class _ChatState extends State<ChatPage> {
  final text = TextEditingController();
  late final stream = db.from('messages').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(200);

  Future<void> send() async {
    final t = text.text.trim();
    if (t.isEmpty) return;
    try {
      await db.from('messages').insert({'recipient_id': widget.otherId, 'body': t});
      text.clear();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Row(children: [Avatar(widget.name, r: 16), const SizedBox(width: 10), Text('@${widget.name}')])),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(children: [
            Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: stream,
                    builder: (c, s) {
                      if (s.hasError) return const Center(child: Empty(Icons.cloud_off, 'Could not load messages.'));
                      if (!s.hasData) return const Center(child: CircularProgressIndicator());
                      final m = s.data!.where((r) => (r['sender_id'] == me && r['recipient_id'] == widget.otherId) || (r['sender_id'] == widget.otherId && r['recipient_id'] == me)).toList();
                      if (m.isEmpty) return const Center(child: Empty(Icons.chat_bubble_outline, 'No messages yet. Say hello.'));
                      return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: m.length,
                          itemBuilder: (c, i) {
                            final mine = m[i]['sender_id'] == me;
                            return Reveal(
                                key: ValueKey(m[i]['id']),
                                child: Align(
                                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 3),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        constraints: const BoxConstraints(maxWidth: 420),
                                        decoration: BoxDecoration(color: mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(m[i]['body'], style: TextStyle(color: mine ? cs.onPrimary : cs.onSurface)),
                                          Text(stamp(m[i]['created_at']), style: TextStyle(fontSize: 11, color: mine ? cs.onPrimary.withAlpha(190) : cs.onSurfaceVariant)),
                                        ]))));
                          });
                    })),
            SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      Expanded(child: TextField(controller: text, maxLength: 1000, decoration: const InputDecoration(hintText: 'Message', counterText: ''), onSubmitted: (_) => send())),
                      const SizedBox(width: 8),
                      IconButton.filled(tooltip: 'Send', onPressed: send, icon: const Icon(Icons.send)),
                    ]))),
          ]),
        ),
      ),
    );
  }
}
