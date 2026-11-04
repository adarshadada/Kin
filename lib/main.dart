import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get db => Supabase.instance.client;
String get me => db.auth.currentUser!.id;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'));
  runApp(const KinApp());
}

void toast(BuildContext c, Object e) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(e is String ? e : e is AuthException ? e.message : e is PostgrestException ? e.message : 'Request failed. Check your connection.')));

String stamp(String s) {
  final d = DateTime.parse(s).toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
}

class KinApp extends StatelessWidget {
  const KinApp({super.key});
  ThemeData _t(Brightness b) {
    final r = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0E7C66),
        brightness: b,
        inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: r)),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: r)),
        cardTheme: CardThemeData(shape: r, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6)));
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Kin',
        theme: _t(Brightness.light),
        darkTheme: _t(Brightness.dark),
        home: StreamBuilder<AuthState>(
            stream: db.auth.onAuthStateChange,
            builder: (c, _) => db.auth.currentSession == null ? const AuthPage() : const Shell()),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthState();
}

class _AuthState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController(), user = TextEditingController();
  bool signup = false, busy = false;

  Future<void> _go() async {
    final e = email.text.trim(), u = user.text.trim().toLowerCase();
    if (signup && !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) return toast(context, 'Username: 3 to 20 letters, numbers or underscores.');
    setState(() => busy = true);
    try {
      if (signup) {
        await db.auth.signUp(email: e, password: pass.text, data: {'username': u});
        if (mounted && db.auth.currentSession == null) toast(context, 'Check your email to confirm your account, then sign in.');
      } else {
        await db.auth.signInWithPassword(email: e, password: pass.text);
      }
    } catch (x) {
      if (mounted) toast(context, x);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              Text('Kin', style: Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              if (signup) ...[TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')), const SizedBox(height: 12)],
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 16),
              FilledButton(onPressed: busy ? null : _go, child: Text(signup ? 'Create account' : 'Sign in')),
              TextButton(onPressed: () => setState(() => signup = !signup), child: Text(signup ? 'I already have an account' : 'Create an account')),
              if (!signup)
                TextButton(
                    onPressed: () async {
                      try {
                        await db.auth.resetPasswordForEmail(email.text.trim());
                        if (mounted) toast(context, 'If that email exists, a reset link was sent.');
                      } catch (x) {
                        if (mounted) toast(context, x);
                      }
                    },
                    child: const Text('Forgot password')),
            ]),
          ),
        ),
      );
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
    final pages = [Feed(key: ValueKey(rev)), const SearchPage(), const Inbox(), ProfilePage(userId: me)];
    final body = Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: pages[i]));
    return Scaffold(
      floatingActionButton: i == 0
          ? FloatingActionButton(
              tooltip: 'New post',
              onPressed: () async {
                if (await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const Compose())) == true) setState(() => rev++);
              },
              child: const Icon(Icons.edit))
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
          : SafeArea(child: body),
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
      final r = await db
          .from('posts')
          .select('*, profiles(username), likes(user_id), comments(count)')
          .inFilter('user_id', ids)
          .order('created_at', ascending: false)
          .range(posts.length, posts.length + 19);
      posts = [...posts, ...r];
      more = r.length == 20;
    } catch (_) {
      err = 'Could not load posts.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => RefreshIndicator(
        onRefresh: () => load(reset: true),
        child: ListView(padding: const EdgeInsets.all(12), physics: const AlwaysScrollableScrollPhysics(), children: [
          if (widget.header != null) widget.header!,
          for (final p in posts) PostCard(key: ValueKey(p['id']), p: p, onGone: () => setState(() => posts.remove(p))),
          if (err != null) Padding(padding: const EdgeInsets.all(16), child: Text(err!)),
          if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (!loading && posts.isEmpty && err == null)
            Padding(
                padding: const EdgeInsets.all(24),
                child: Text(widget.userId == null ? 'Your feed is empty. Find people in Search, or write your first post.' : 'No posts yet.')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: InkWell(
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(userId: p['user_id']))),
                    child: Text('@$name', style: const TextStyle(fontWeight: FontWeight.w600)))),
            Text(stamp(p['created_at']), style: Theme.of(c).textTheme.bodySmall),
            PopupMenuButton<String>(
                onSelected: menu,
                itemBuilder: (_) => [PopupMenuItem(value: own ? 'delete' : 'report', child: Text(own ? 'Delete' : 'Report'))]),
          ]),
          if ((p['body'] as String).isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(p['body'])),
          if (p['media_url'] != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(p['media_url'], fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Text('Image unavailable'))),
          Row(children: [
            IconButton(tooltip: liked ? 'Unlike' : 'Like', onPressed: like, icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red.shade700 : null)),
            Text('$n'),
            const SizedBox(width: 8),
            IconButton(
                tooltip: 'Comments',
                onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CommentsPage(postId: p['id']))),
                icon: const Icon(Icons.mode_comment_outlined)),
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
  var img;
  String ext = 'jpg';
  bool busy = false;

  Future<void> pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    final b = await x.readAsBytes(), e = x.name.split('.').last.toLowerCase();
    if (!mounted) return;
    if (b.length > 5 * 1024 * 1024) return toast(context, 'Image must be under 5 MB.');
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
        await db.storage.from('media').uploadBinary(path, img, fileOptions: FileOptions(contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
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
        appBar: AppBar(title: const Text('New post'), actions: [TextButton(onPressed: busy ? null : post, child: const Text('Post'))]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: text, maxLines: 6, maxLength: 500, decoration: const InputDecoration(hintText: 'What is on your mind?')),
          if (img != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(img, height: 220, fit: BoxFit.cover)),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: pick, icon: const Icon(Icons.image_outlined), label: const Text('Add image'))),
        ]),
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
                          ? const Center(child: Text('No comments yet.'))
                          : ListView(children: [
                              for (final r in rows!) ListTile(title: Text('@${r['profiles']['username']}'), subtitle: Text(r['body']), trailing: Text(stamp(r['created_at']), style: Theme.of(c).textTheme.bodySmall))
                            ])),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: text, maxLength: 300, decoration: const InputDecoration(hintText: 'Add a comment', counterText: ''), onSubmitted: (_) => send())),
                        IconButton(tooltip: 'Send', onPressed: send, icon: const Icon(Icons.send)),
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
                ? const Center(child: Text('Search for people by username.'))
                : rows!.isEmpty
                    ? const Center(child: Text('No users found.'))
                    : ListView(children: [
                        for (final r in rows!)
                          ListTile(title: Text('@${r['username']}'), subtitle: Text(r['bio'], maxLines: 1), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(userId: r['id']))))
                      ])),
      ]);
}

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});
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

  @override
  Widget build(BuildContext c) {
    final p = prof;
    return Scaffold(
      appBar: AppBar(title: Text(p == null ? '' : '@${p['username']}'), actions: [
        if (own && p != null) IconButton(tooltip: 'Edit bio', onPressed: editBio, icon: const Icon(Icons.edit_outlined)),
        if (own) IconButton(tooltip: 'Sign out', onPressed: db.auth.signOut, icon: const Icon(Icons.logout)),
      ]),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : Feed(
              userId: widget.userId,
              header: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((p['bio'] as String).isNotEmpty) Text(p['bio']),
                  const SizedBox(height: 8),
                  Text('$followers followers   $following following', style: Theme.of(c).textTheme.bodyMedium),
                  if (!own)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          FilledButton(onPressed: toggleFollow, child: Text(isFollowing ? 'Unfollow' : 'Follow')),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ChatPage(otherId: widget.userId, name: p['username']))), child: const Text('Message')),
                        ])),
                ]),
              )),
    );
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
      final ps = last.isEmpty ? [] : await db.from('profiles').select('id, username').inFilter('id', last.keys.toList());
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
          ? const Center(child: Text('No conversations. Open a profile and tap Message.'))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(children: [
                for (final r in rows!)
                  ListTile(
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
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text('@${widget.name}')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(children: [
              Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: stream,
                      builder: (c, s) {
                        if (s.hasError) return const Center(child: Text('Could not load messages.'));
                        if (!s.hasData) return const Center(child: CircularProgressIndicator());
                        final m = s.data!.where((r) => (r['sender_id'] == me && r['recipient_id'] == widget.otherId) || (r['sender_id'] == widget.otherId && r['recipient_id'] == me)).toList();
                        if (m.isEmpty) return const Center(child: Text('No messages yet.'));
                        return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: m.length,
                            itemBuilder: (c, i) {
                              final mine = m[i]['sender_id'] == me;
                              return Align(
                                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 3),
                                      padding: const EdgeInsets.all(10),
                                      constraints: const BoxConstraints(maxWidth: 420),
                                      decoration: BoxDecoration(color: mine ? Theme.of(c).colorScheme.primaryContainer : Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m[i]['body']), Text(stamp(m[i]['created_at']), style: Theme.of(c).textTheme.labelSmall)])));
                            });
                      })),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: text, maxLength: 1000, decoration: const InputDecoration(hintText: 'Message', counterText: ''), onSubmitted: (_) => send())),
                        IconButton(tooltip: 'Send', onPressed: send, icon: const Icon(Icons.send)),
                      ]))),
            ]),
          ),
        ),
      );
}
