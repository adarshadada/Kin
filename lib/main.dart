import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kUrl = 'https://gkpjicnihgicrsndjltl.supabase.co';
const kKey = 'sb_publishable_cx1YkMueniFpjQJTk-J7AQ_64LGWzos';
const lime = Color(0xFFB8F34A);
const ink = Color(0xFF0B0B0B);

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
  if (e is StorageException) return e.message;
  return 'Request failed. Check your connection.';
}

void toast(BuildContext c, Object e) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(errText(e))));

String stamp(String s) {
  final d = DateTime.parse(s).toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
}

String ago(String s) {
  final d = DateTime.now().difference(DateTime.parse(s).toLocal());
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return stamp(s).substring(0, 10);
}

Future<String> uploadMedia(Uint8List b, String ext, String prefix) async {
  final path = '$me/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  await db.storage.from('media').uploadBinary(path, b, fileOptions: FileOptions(contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
  return db.storage.from('media').getPublicUrl(path);
}

Future<({Uint8List bytes, String ext})?> pickImg(BuildContext c, {double max = 1600}) async {
  final src = await showModalBottomSheet<ImageSource>(
      context: c,
      builder: (s) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(s, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(s, ImageSource.gallery)),
          ])));
  if (src == null) return null;
  final x = await ImagePicker().pickImage(source: src, maxWidth: max, imageQuality: 85);
  if (x == null) return null;
  final b = await x.readAsBytes();
  var e = x.name.split('.').last.toLowerCase();
  if (e == 'jpeg') e = 'jpg';
  if (!c.mounted) return null;
  if (b.length > 25 * 1024 * 1024) {
    toast(c, 'Image must be under 25 MB.');
    return null;
  }
  if (!['jpg', 'png', 'webp'].contains(e)) {
    toast(c, 'Use a JPG, PNG or WebP image.');
    return null;
  }
  return (bytes: b, ext: e);
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
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(9.5 * u)), Paint()..color = lime);
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final x = (8 + 16 * i / 80) * u, y = (16 - 3 * math.sin(4 * math.pi * i / 80)) * u;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    c.drawPath(path, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2.3 * u..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_) => false;
}

class Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double r;
  const Avatar(this.name, {super.key, this.url, this.r = 18});
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return CircleAvatar(
        radius: r,
        backgroundColor: cs.primaryContainer,
        foregroundImage: url == null ? null : NetworkImage(url!),
        onForegroundImageError: url == null ? null : (_, __) {},
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
    final cs = ColorScheme.fromSeed(seedColor: lime, brightness: b).copyWith(
      primary: dark ? lime : ink,
      onPrimary: dark ? ink : Colors.white,
      primaryContainer: dark ? const Color(0xFF2A3A10) : const Color(0xFFE6FBB0),
      onPrimaryContainer: dark ? lime : ink,
    );
    final line = dark ? const Color(0xFF26302C) : const Color(0xFFE2E5E0);
    final bg = dark ? const Color(0xFF0B0F0D) : Colors.white;
    final fill = dark ? const Color(0xFF171E1B) : const Color(0xFFF4F5F2);
    final r = BorderRadius.circular(8);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: fill, border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 44), shape: RoundedRectangleBorder(borderRadius: r))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 44), side: BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: r))),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: bg, surfaceTintColor: Colors.transparent, indicatorColor: Colors.transparent, height: 56, labelBehavior: NavigationDestinationLabelBehavior.alwaysHide),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: bg, indicatorColor: cs.primaryContainer),
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
              AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(titles[mode], key: ValueKey(mode), style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(height: 4),
              Text('Posts, photos and stories from people you follow.', style: TextStyle(color: cs.onSurfaceVariant)),
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
              FilledButton(onPressed: busy ? null : _go, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(labels[mode])),
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
    (Icons.add_box_outlined, Icons.add_box, 'New post'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Messages'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  Future<void> _sel(int v) async {
    if (v == 2) {
      if (await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const Compose())) == true) setState(() => rev++);
    } else {
      setState(() => i = v);
    }
  }

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.of(c).size.width >= 700;
    final pages = [Feed(key: ValueKey(rev), header: StoryBar(key: ValueKey(rev))), const SearchPage(), const SizedBox(), const Inbox(), ProfilePage(userId: me, embedded: true)];
    final body = Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey('$i-$rev'), child: pages[i]))));
    return Scaffold(
      appBar: AppBar(title: Row(children: [const KinLogo(size: 28), const SizedBox(width: 10), Text(i == 0 ? 'Kin' : _d[i].$3, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20))])),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(selectedIndex: i, onDestinationSelected: _sel, destinations: [for (final d in _d) NavigationDestination(icon: Icon(d.$1, size: 28), selectedIcon: Icon(d.$2, size: 28), label: d.$3)]),
      body: wide
          ? Row(children: [
              NavigationRail(selectedIndex: i, labelType: NavigationRailLabelType.all, onDestinationSelected: _sel, destinations: [for (final d in _d) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))]),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
    );
  }
}

class StoryBar extends StatefulWidget {
  const StoryBar({super.key});
  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  Map<String, List<Map<String, dynamic>>> groups = {};
  Map<String, dynamic>? mine;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await db.from('follows').select('followee_id').eq('follower_id', me);
      final ids = [me, ...f.map((r) => r['followee_id'] as String)];
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
      final r = await db.from('stories').select('*, profiles(username, avatar_url)').inFilter('user_id', ids).gte('created_at', since).order('created_at');
      final g = <String, List<Map<String, dynamic>>>{};
      for (final s in r) {
        g.putIfAbsent(s['user_id'] as String, () => []).add(s);
      }
      final p = await db.from('profiles').select('username, avatar_url').eq('id', me).single();
      if (mounted) {
        setState(() {
          groups = g;
          mine = p;
        });
      }
    } catch (_) {}
  }

  Future<void> add() async {
    try {
      final img = await pickImg(context, max: 1440);
      if (img == null) return;
      final url = await uploadMedia(img.bytes, img.ext, 'story');
      await db.from('stories').insert({'media_url': url});
      load();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  Future<void> view(List<Map<String, dynamic>> items) async {
    await Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => StoryViewer(items: items)));
    load();
  }

  Widget _tile(String name, String? url, bool ring, VoidCallback onTap, {VoidCallback? onPlus}) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Stack(children: [
            GestureDetector(
                onTap: onTap,
                child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring ? lime : Theme.of(context).dividerColor, width: ring ? 3 : 1.5)),
                    child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: bg), child: Avatar(name, url: url, r: 26)))),
            if (onPlus != null)
              Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                      onTap: onPlus,
                      child: Container(width: 22, height: 22, decoration: BoxDecoration(color: lime, shape: BoxShape.circle, border: Border.all(color: bg, width: 2)), child: const Icon(Icons.add, size: 14, color: ink)))),
          ]),
          const SizedBox(height: 4),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final own = groups[me];
    final others = groups.entries.where((e) => e.key != me).toList();
    return Column(children: [
      SizedBox(
          height: 104,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
            _tile('Your story', mine?['avatar_url'], own != null, () => own != null ? view(own) : add(), onPlus: add),
            for (final e in others) _tile(e.value.first['profiles']['username'], e.value.first['profiles']['avatar_url'], true, () => view(e.value)),
          ])),
      const Divider(height: 1),
    ]);
  }
}

class StoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const StoryViewer({super.key, required this.items});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) next();
    });
  int i = 0;

  @override
  void initState() {
    super.initState();
    ctl.forward();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void next() {
    if (i < widget.items.length - 1) {
      setState(() => i++);
      ctl.forward(from: 0);
    } else {
      Navigator.pop(context);
    }
  }

  void prev() {
    if (i > 0) setState(() => i--);
    ctl.forward(from: 0);
  }

  Future<void> remove() async {
    try {
      await db.from('stories').delete().eq('id', widget.items[i]['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.items[i], pr = s['profiles'];
    final w = MediaQuery.of(c).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (d) => d.localPosition.dx < w / 3 ? prev() : next(),
          onLongPressStart: (_) => ctl.stop(),
          onLongPressEnd: (_) => ctl.forward(),
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
          },
          child: Stack(children: [
            Positioned.fill(child: Image.network(s['media_url'], key: ValueKey(s['id']), fit: BoxFit.contain, loadingBuilder: (_, w, p) => p == null ? w : const Center(child: CircularProgressIndicator()), errorBuilder: (_, __, ___) => const Center(child: Text('Story unavailable', style: TextStyle(color: Colors.white))))),
            Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Column(children: [
                  Row(children: [
                    for (var j = 0; j < widget.items.length; j++)
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: AnimatedBuilder(animation: ctl, builder: (_, __) => LinearProgressIndicator(value: j < i ? 1 : (j == i ? ctl.value : 0), minHeight: 3, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation(Colors.white))))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Avatar(pr['username'], url: pr['avatar_url'], r: 16),
                    const SizedBox(width: 8),
                    Text('@${pr['username']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(ago(s['created_at']), style: const TextStyle(color: Colors.white70)),
                    const Spacer(),
                    if (s['user_id'] == me) IconButton(tooltip: 'Delete story', onPressed: remove, icon: const Icon(Icons.delete_outline, color: Colors.white)),
                    IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                  ]),
                ])),
          ]),
        ),
      ),
    );
  }
}

class Feed extends StatefulWidget {
  final Widget? header;
  const Feed({super.key, this.header});
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
      final f = await db.from('follows').select('followee_id').eq('follower_id', me);
      final ids = [me, ...f.map((r) => r['followee_id'] as String)];
      final r = await db.from('posts').select('*, profiles(username, avatar_url), likes(user_id), comments(count)').inFilter('user_id', ids).order('created_at', ascending: false).range(posts.length, posts.length + 19);
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
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          if (widget.header != null) widget.header!,
          for (final p in posts) Reveal(key: ValueKey(p['id']), child: PostCard(p: p, onGone: () => setState(() => posts.remove(p)))),
          if (err != null) Empty(Icons.cloud_off, err!),
          if (loading && posts.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (!loading && posts.isEmpty && err == null) const Empty(Icons.dynamic_feed_outlined, 'Your feed is empty.\nFind people in Search, or share your first post.'),
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
    final own = p['user_id'] == me, pr = p['profiles'], name = pr['username'] as String, body = p['body'] as String;
    final cc = (p['comments'] as List).isEmpty ? 0 : p['comments'][0]['count'] as int;
    final cs = Theme.of(c).colorScheme;
    void comments() => Navigator.push(c, MaterialPageRoute(builder: (_) => CommentsPage(postId: p['id'])));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Row(children: [
            InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(userId: p['user_id']))),
                child: Row(children: [Avatar(name, url: pr['avatar_url'], r: 16), const SizedBox(width: 10), Text(name, style: const TextStyle(fontWeight: FontWeight.w700))])),
            const Spacer(),
            PopupMenuButton<String>(onSelected: menu, itemBuilder: (_) => [PopupMenuItem(value: own ? 'delete' : 'report', child: Text(own ? 'Delete' : 'Report'))]),
          ])),
      if (p['media_url'] != null)
        GestureDetector(
            onDoubleTap: liked ? null : like,
            child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 520), child: Image.network(p['media_url'], fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Image unavailable'))))),
      Row(children: [
        IconButton(
            tooltip: liked ? 'Unlike' : 'Like',
            onPressed: like,
            icon: AnimatedSwitcher(duration: const Duration(milliseconds: 180), transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w), child: Icon(liked ? Icons.favorite : Icons.favorite_border, size: 28, key: ValueKey(liked), color: liked ? Colors.red.shade700 : null))),
        IconButton(tooltip: 'Comments', onPressed: comments, icon: const Icon(Icons.mode_comment_outlined, size: 26)),
      ]),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (n > 0) Text(n == 1 ? '1 like' : '$n likes', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text.rich(TextSpan(children: [TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: body)])),
            if (cc > 0) InkWell(onTap: comments, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(cc == 1 ? 'View 1 comment' : 'View all $cc comments', style: TextStyle(color: cs.onSurfaceVariant)))),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(ago(p['created_at']), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
          ])),
      const SizedBox(height: 16),
    ]);
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
    final r = await pickImg(context);
    if (r != null) {
      setState(() {
        img = r.bytes;
        ext = r.ext;
      });
    }
  }

  Future<void> post() async {
    final t = text.text.trim();
    if (t.isEmpty && img == null) return;
    setState(() => busy = true);
    try {
      final url = img == null ? null : await uploadMedia(img!, ext, 'post');
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
        appBar: AppBar(title: const Text('New post'), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: busy ? null : post, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Share')))]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: img == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Stack(children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(img!, width: double.infinity, height: 320, fit: BoxFit.cover)),
                            Positioned(top: 4, right: 4, child: IconButton.filledTonal(tooltip: 'Remove image', onPressed: () => setState(() => img = null), icon: const Icon(Icons.close))),
                          ]))),
              TextField(controller: text, maxLines: 5, maxLength: 500, decoration: const InputDecoration(hintText: 'Write a caption')),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(img == null ? 'Add photo' : 'Change photo'))),
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
      final r = await db.from('comments').select('*, profiles(username, avatar_url)').eq('post_id', widget.postId).order('created_at').limit(200);
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
                                Reveal(key: ValueKey(r['id']), child: ListTile(leading: Avatar(r['profiles']['username'], url: r['profiles']['avatar_url']), title: Text.rich(TextSpan(children: [TextSpan(text: '${r['profiles']['username']}  ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: r['body'])])), subtitle: Text(ago(r['created_at']))))
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
      final r = await db.from('profiles').select('id, username, bio, avatar_url').ilike('username', '%$q%').neq('id', me).limit(20);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext c) => Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onSubmitted: run, textInputAction: TextInputAction.search, decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)))),
        Expanded(
            child: rows == null
                ? const Center(child: Empty(Icons.search, 'Search for people by username.'))
                : rows!.isEmpty
                    ? const Center(child: Empty(Icons.person_search_outlined, 'No users found.'))
                    : ListView(children: [
                        for (final r in rows!)
                          Reveal(key: ValueKey(r['id']), child: ListTile(leading: Avatar(r['username'], url: r['avatar_url'], r: 22), title: Text(r['username'], style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(r['bio'], maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(userId: r['id'])))))
                      ])),
      ]);
}

class PostPage extends StatelessWidget {
  final Map<String, dynamic> p;
  const PostPage({super.key, required this.p});
  @override
  Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Post')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(children: [PostCard(p: p, onGone: () => Navigator.pop(c))]))));
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
  List<Map<String, dynamic>> posts = [];
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
      final ps = await db.from('posts').select('*, profiles(username, avatar_url), likes(user_id), comments(count)').eq('user_id', id).order('created_at', ascending: false).limit(60);
      if (mounted) {
        setState(() {
          prof = p;
          posts = ps;
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

  Widget _stat(String n, String l) => Expanded(child: Column(children: [Text(n, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text(l, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))]));

  Widget _tile(BuildContext c, Map<String, dynamic> p) {
    final cs = Theme.of(c).colorScheme;
    return InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => PostPage(p: p))),
        child: p['media_url'] != null
            ? Image.network(p['media_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest))
            : Container(color: cs.primaryContainer, padding: const EdgeInsets.all(8), alignment: Alignment.center, child: Text(p['body'], maxLines: 5, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13))));
  }

  @override
  Widget build(BuildContext c) {
    final p = prof;
    Widget body;
    if (p == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Avatar(p['username'], url: p['avatar_url'], r: 40), const SizedBox(width: 12), _stat('${posts.length}', 'posts'), _stat('$followers', 'followers'), _stat('$following', 'following')]),
                const SizedBox(height: 12),
                Text(p['username'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if ((p['bio'] as String).isNotEmpty) Text(p['bio']),
                const SizedBox(height: 12),
                if (own)
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(c, MaterialPageRoute(builder: (_) => EditProfile(prof: p)));
                              load();
                            },
                            child: const Text('Edit profile'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: db.auth.signOut, child: const Text('Sign out'))),
                  ])
                else
                  Row(children: [
                    Expanded(child: isFollowing ? OutlinedButton(onPressed: toggleFollow, child: const Text('Following')) : FilledButton(onPressed: toggleFollow, child: const Text('Follow'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ChatPage(otherId: widget.userId, name: p['username'], url: p['avatar_url']))), child: const Text('Message'))),
                  ]),
              ])),
          const Divider(height: 1),
          if (posts.isEmpty)
            const Empty(Icons.photo_library_outlined, 'No posts yet.')
          else
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                itemCount: posts.length,
                itemBuilder: (c, i) => _tile(c, posts[i])),
        ]),
      );
    }
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(p?['username'] ?? '')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: body)));
  }
}

class EditProfile extends StatefulWidget {
  final Map<String, dynamic> prof;
  const EditProfile({super.key, required this.prof});
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late final bio = TextEditingController(text: widget.prof['bio']);
  late String? avatar = widget.prof['avatar_url'];
  bool busy = false;

  Future<void> photo() async {
    try {
      final img = await pickImg(context, max: 2000);
      if (img == null || !mounted) return;
      final out = await Navigator.push<Uint8List>(context, MaterialPageRoute(builder: (_) => AvatarEditor(bytes: img.bytes)));
      if (out == null) return;
      setState(() => busy = true);
      final url = await uploadMedia(out, 'png', 'avatar');
      await db.from('profiles').update({'avatar_url': url}).eq('id', me);
      if (mounted) setState(() => avatar = url);
    } catch (e) {
      if (mounted) toast(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await db.from('profiles').update({'bio': bio.text.trim()}).eq('id', me);
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
        appBar: AppBar(title: const Text('Edit profile'), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: busy ? null : save, child: const Text('Save')))]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Center(child: Avatar(widget.prof['username'], url: avatar, r: 56)),
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: busy ? null : photo, child: const Text('Change profile photo'))),
              const SizedBox(height: 16),
              TextField(controller: bio, maxLength: 160, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
              if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            ]),
          ),
        ),
      );
}

class AvatarEditor extends StatefulWidget {
  final Uint8List bytes;
  const AvatarEditor({super.key, required this.bytes});
  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  final key = GlobalKey();
  int f = 0;
  double bright = 0;
  bool busy = false;
  static const names = ['Original', 'Mono', 'Warm', 'Cool', 'Fade'];
  static const mats = <List<double>>[
    [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
    [0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0],
    [1.1, 0, 0, 0, 10, 0, 1, 0, 0, 0, 0, 0, 0.9, 0, -10, 0, 0, 0, 1, 0],
    [0.9, 0, 0, 0, -10, 0, 1, 0, 0, 0, 0, 0, 1.1, 0, 10, 0, 0, 0, 1, 0],
    [0.85, 0, 0, 0, 30, 0, 0.85, 0, 0, 30, 0, 0, 0.85, 0, 30, 0, 0, 0, 1, 0],
  ];

  ColorFilter get filter {
    final m = List<double>.from(mats[f]);
    for (final k in [4, 9, 14]) {
      m[k] += bright * 255;
    }
    return ColorFilter.matrix(m);
  }

  Future<void> done() async {
    setState(() => busy = true);
    try {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final im = await b.toImage(pixelRatio: 512 / b.size.width);
      final bd = await im.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) Navigator.pop(context, bd!.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        toast(context, 'Could not process the photo.');
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final size = math.min(MediaQuery.of(c).size.width - 32, 360.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit photo'), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: busy ? null : done, child: const Text('Done')))]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
                child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(children: [
                      Positioned.fill(
                          child: RepaintBoundary(
                              key: key,
                              child: ClipRect(child: ColorFiltered(colorFilter: filter, child: InteractiveViewer(minScale: 1, maxScale: 6, child: Image.memory(widget.bytes, width: size, height: size, fit: BoxFit.cover)))))),
                      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CirclePainter()))),
                    ]))),
            const SizedBox(height: 8),
            const Center(child: Text('Pinch to zoom, drag to move')),
            const SizedBox(height: 16),
            SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (var i = 0; i < names.length; i++) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(names[i]), selected: f == i, onSelected: (_) => setState(() => f = i))),
                ])),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.brightness_6_outlined),
              Expanded(child: Slider(value: bright, min: -0.3, max: 0.3, onChanged: (v) => setState(() => bright = v))),
            ]),
            if (busy) const Center(child: CircularProgressIndicator()),
          ]),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero), r = s.width / 2;
    c.drawPath(Path()..fillType = PathFillType.evenOdd..addRect(Offset.zero & s)..addOval(Rect.fromCircle(center: ctr, radius: r)), Paint()..color = Colors.black54);
    c.drawCircle(ctr, r, Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_) => false;
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
      final ps = last.isEmpty ? <Map<String, dynamic>>[] : await db.from('profiles').select('id, username, avatar_url').inFilter('id', last.keys.toList());
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
                      leading: Avatar(r['username'], url: r['avatar_url'], r: 24),
                      title: Text(r['username'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(r['last'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        await Navigator.push(c, MaterialPageRoute(builder: (_) => ChatPage(otherId: r['id'], name: r['username'], url: r['avatar_url'])));
                        load();
                      })
              ]));
}

class ChatPage extends StatefulWidget {
  final String otherId, name;
  final String? url;
  const ChatPage({super.key, required this.otherId, required this.name, this.url});
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
      appBar: AppBar(title: Row(children: [Avatar(widget.name, url: widget.url, r: 16), const SizedBox(width: 10), Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700))])),
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
                                        decoration: BoxDecoration(color: mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
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
