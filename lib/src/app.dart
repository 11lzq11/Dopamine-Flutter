import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ffi/dopamine_ffi.dart';

void runDopamineApp() => runApp(const DopamineApp());

class DopamineApp extends StatelessWidget {
  const DopamineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF67AD5B),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Dopamine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF08130C),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/package-managers': (_) => const PackageManagerScreen(),
        '/credits': (_) => const CreditsScreen(),
        '/licenses': (_) => const LicenseScreen(),
      },
    );
  }
}

class JailbreakController {
  JailbreakController._();

  static final instance = JailbreakController._();

  final state = ValueNotifier<Map<String, dynamic>>({});
  final logs = <String>[];
  Timer? _timer;

  bool get isJailbroken => state.value['jailbroken'] == true;
  bool get supported => state.value['supported'] != false;
  String get supportString =>
      state.value['supportString']?.toString() ?? 'iOS 15.0 - 18.7.1 / 26.0 - 26.0.1';

  void refresh() {
    try {
      state.value = DopamineFfi.instance().state();
    } catch (error) {
      state.value = {'unsupported': error.toString(), 'supported': false};
    }
  }

  void beginLogCapture() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 80), (_) {
      for (var i = 0; i < 32; i++) {
        final line = DopamineFfi.instance().nextLog();
        if (line.isEmpty) break;
        logs.add(line);
      }
    });
  }

  Future<bool> start({
    required bool removeJailbreak,
    required bool tweakInjection,
    required bool iDownload,
    required bool appJit,
    required bool verboseLogs,
    required double jetsamMultiplier,
  }) async {
    logs.clear();
    refresh();
    try {
      final ok = DopamineFfi.instance().startJailbreak(
        removeJailbreak: removeJailbreak,
        tweakInjection: tweakInjection,
        iDownload: iDownload,
        appJit: appJit,
        verboseLogs: verboseLogs,
        jetsamMultiplier: jetsamMultiplier,
      );
      beginLogCapture();
      return ok;
    } catch (error) {
      logs.add(error.toString());
      return false;
    }
  }

  void action(String action, {Map<String, dynamic> arguments = const {}}) {
    try {
      DopamineFfi.instance().action(action, arguments: arguments);
    } catch (error) {
      logs.add(error.toString());
    }
    refresh();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = JailbreakController.instance;
  final prefs = SettingsStore.instance;

  @override
  void initState() {
    super.initState();
    controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dopamine', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${controller.supportString} · by opa334', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  FilledMenu(children: [
                    MenuTile(icon: Icons.tune_rounded, label: 'Settings', onTap: () => Navigator.pushNamed(context, '/settings')),
                    MenuTile(icon: Icons.refresh_rounded, label: 'Restart SpringBoard', enabled: controller.isJailbroken, onTap: () => controller.action('respring')),
                    MenuTile(icon: Icons.restart_alt_rounded, label: 'Reboot Userspace', enabled: controller.isJailbroken, onTap: () => controller.action('userspaceReboot')),
                    MenuTile(icon: Icons.info_outline_rounded, label: 'Credits', onTap: () => Navigator.pushNamed(context, '/credits')),
                  ]),
                  const SizedBox(height: 44),
                  FilledButton.icon(
                    onPressed: controller.supported && !controller.isJailbroken ? () async { final started = await controller.start(removeJailbreak: prefs.removeJailbreakEnabled, tweakInjection: prefs.tweakInjectionEnabled, iDownload: prefs.iDownloadEnabled, appJit: prefs.appJitEnabled, verboseLogs: prefs.verboseLogs, jetsamMultiplier: prefs.jetsamMultiplier); if (mounted) setState(() {}); if (!started && mounted) showSnack(context, 'Unable to start jailbreak'); } : null,
                    icon: Icon(controller.supported ? Icons.lock_open_rounded : Icons.lock_outline_rounded),
                    label: Text(!controller.supported ? 'Unsupported' : controller.isJailbroken ? 'Jailbroken' : 'Jailbreak'),
                  ),
                  const SizedBox(height: 18),
                  LogPreview(logs: controller.logs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class LogPreview extends StatelessWidget {
  const LogPreview({super.key, required this.logs});
  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();
    return Card(color: Colors.black.withValues(alpha: .35), child: SizedBox(height: 130, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: logs.length, itemBuilder: (_, index) => SelectableText('> ${logs[index]}'))));
  }
}

class FilledMenu extends StatelessWidget {
  const FilledMenu({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Column(children: [for (var i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const Divider(height: 1)]]));
}

class MenuTile extends StatelessWidget {
  const MenuTile({super.key, required this.icon, required this.label, this.onTap, this.enabled = true});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(enabled: onTap != null && enabled, leading: Icon(icon), title: Text(label), onTap: enabled ? onTap : null);
}

class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final instance = SettingsStore._();

  bool tweakInjectionEnabled = true;
  bool verboseLogs = false;
  bool iDownloadEnabled = false;
  bool appJitEnabled = true;
  double jetsamMultiplier = 6;
  bool removeJailbreakEnabled = false;
  bool bootLogoEnabled = true;
  bool customBootLogoEnabled = false;
  String theme = 'default';

  void update(VoidCallback mutate) {
    mutate();
    notifyListeners();
    try {
      JailbreakController.instance.action('setPreference', arguments: {
        'tweakInjectionEnabled': tweakInjectionEnabled,
        'verboseLogsEnabled': verboseLogs,
        'idownloadEnabled': iDownloadEnabled,
        'appJITEnabled': appJitEnabled,
        'jetsamMultiplier': jetsamMultiplier,
        'removeJailbreakEnabled': removeJailbreakEnabled,
        'bootlogoEnabled': bootLogoEnabled,
        'customBootlogoEnabled': customBootLogoEnabled,
        'theme': theme,
      });
    } catch (_) {}
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(8, 20, 8, 8), child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelLarge));
}

class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), elevation: 0, clipBehavior: Clip.antiAlias, child: child);
}

Future<bool> confirm(BuildContext context, {required String title, required String body}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title), content: Text(body),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
    ),
  );
  return result ?? false;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = SettingsStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const SectionLabel('Exploits'),
      const OptionCard(child: ListTile(title: Text('Kernel Exploit'), subtitle: Text('Automatic / preferred exploit'), trailing: Icon(Icons.auto_awesome_outlined))),
      const SectionLabel('Jailbreak Settings'),
      OptionCard(child: SwitchListTile(title: const Text('Tweak Injection'), value: store.tweakInjectionEnabled, onChanged: (v) => setState(() => store.update(() => store.tweakInjectionEnabled = v)))),
      OptionCard(child: SwitchListTile(title: const Text('Verbose Logs'), value: store.verboseLogs, onChanged: (v) => setState(() => store.update(() => store.verboseLogs = v)))),
      OptionCard(child: SwitchListTile(title: const Text('iDownload (Developer Shell)'), value: store.iDownloadEnabled, onChanged: (v) => setState(() => store.update(() => store.iDownloadEnabled = v)))),
      OptionCard(child: SwitchListTile(title: const Text('Allow JIT in Apps'), value: store.appJitEnabled, onChanged: (v) => setState(() => store.update(() => store.appJitEnabled = v)))),
      OptionCard(child: ListTile(title: const Text('Jetsam Multiplier'), subtitle: Text(store.jetsamMultiplier == 6 ? '3x (Recommended)' : '${store.jetsamMultiplier / 2}x'), trailing: DropdownButton<double>(value: store.jetsamMultiplier, items: const [2, 3, 4, 5, 6, 7, 8].map((v) => DropdownMenuItem(value: v.toDouble(), child: Text(v == 6 ? '3x' : '${v / 2}x'))).toList(), onChanged: (v) { if (v != null) setState(() => store.update(() => store.jetsamMultiplier = v)); }))),
      OptionCard(child: SwitchListTile(title: const Text('Remove Jailbreak'), value: store.removeJailbreakEnabled, onChanged: (value) async {
        var accepted = !value || await confirm(context, title: 'Remove Jailbreak', body: 'All jailbreak-related files will be removed on the next jailbreak.');
        if (accepted) setState(() => store.update(() => store.removeJailbreakEnabled = value));
      })),
      const SectionLabel('Actions'),
      OptionCard(child: ListTile(leading: const Icon(Icons.apps_rounded), title: const Text('Refresh Jailbreak Apps'), onTap: () => JailbreakController.instance.action('refreshApps'))),
      OptionCard(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Reinstall Package Managers'), onTap: () => Navigator.pushNamed(context, '/package-managers'))),
      OptionCard(child: ListTile(leading: const Icon(Icons.visibility_off_outlined), title: const Text('Hide Jailbreak'), onTap: () => JailbreakController.instance.action('hideJailbreak'))),
      const SectionLabel('Customization'),
      OptionCard(child: ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Theme'), subtitle: const Text('Material 3 Dynamic'), trailing: SegmentedButton<String>(segments: const [ButtonSegment(value: 'default', label: Text('Green')), ButtonSegment(value: 'ellekit', label: Text('ElleKit')), ButtonSegment(value: 'purple', label: Text('Dusk'))], selected: {store.theme}, onSelectionChanged: (selection) => setState(() => store.update(() => store.theme = selection.first))))),
      const SectionLabel('Boot Logo'),
      OptionCard(child: SwitchListTile(title: const Text('Enabled'), value: store.bootLogoEnabled, onChanged: (v) => setState(() => store.update(() => store.bootLogoEnabled = v)))),
      if (store.bootLogoEnabled)
        OptionCard(child: SwitchListTile(title: const Text('Custom Boot Logo'), value: store.customBootLogoEnabled, onChanged: (v) => setState(() => store.update(() => store.customBootLogoEnabled = v)))),
      if (store.bootLogoEnabled && store.customBootLogoEnabled)
        OptionCard(child: ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Select Image'), subtitle: const Text('Uses native image picker bridge'), onTap: () => JailbreakController.instance.action('selectBootLogoImage'))),
    ]));
  }
}

class PackageManagerScreen extends StatefulWidget {
  const PackageManagerScreen({super.key});

  @override
  State<PackageManagerScreen> createState() => _PackageManagerScreenState();
}

class _PackageManagerScreenState extends State<PackageManagerScreen> {
  bool sileo = true;
  bool zebra = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Select Package Manager(s)')), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Text('If you are unsure which one to select, select Sileo', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),
      Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
        FilterChip(selected: sileo, label: const Text('Sileo'), onSelected: (v) => setState(() => sileo = v)),
        FilterChip(selected: zebra, label: const Text('Zebra'), onSelected: (v) => setState(() => zebra = v)),
      ])])),
      bottomNavigationBar: SafeArea(minimum: const EdgeInsets.all(24), child: FilledButton.icon(onPressed: sileo || zebra ? () { JailbreakController.instance.action('setPackageManagers', arguments: {'enabled': [if (sileo) 'org.coolstar.SileoStore', if (zebra) 'xyz.willy.Zebra']}); Navigator.pop(context); } : null, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Continue')))));
  }
}

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Credits')), body: ListView(padding: const EdgeInsets.all(16), children: [
      OptionCard(child: ListTile(leading: const Icon(Icons.code_rounded), title: const Text('Source Code'), subtitle: const Text('Copies github.com/opa334/Dopamine to clipboard'), onTap: () => Clipboard.setData(const ClipboardData(text: 'https://github.com/opa334/Dopamine')))),
      OptionCard(child: ListTile(leading: const Icon(Icons.forum_rounded), title: const Text('Discord'), subtitle: const Text('Copies discord.gg/jb to clipboard'), onTap: () => Clipboard.setData(const ClipboardData(text: 'https://discord.gg/jb')))),
      OptionCard(child: ListTile(leading: const Icon(Icons.gavel_rounded), title: const Text('Licenses'), onTap: () => Navigator.pushNamed(context, '/licenses'))),
      const SectionLabel('Developers'), const CreditNames(names: ['opa334', 'kok3shidoll', 'Alfie', 'Clarity', 'staturnz', 'wh1te4ever']),
      const SectionLabel('UI and Design'), const CreditNames(names: ['tomt000', 'sourcelocation', 'xerus']),
      const SectionLabel('Based on projects by'), const CreditNames(names: ['Fugu15', 'Pinauten GmbH', 'tihmstar', 'ElleKit', 'ChOma', 'XPF', 'Procursus', 'Sileo', 'Zebra']),
    ]));
  }
}

class CreditNames extends StatelessWidget {
  const CreditNames({super.key, required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: [for (final name in names) Chip(label: Text(name))])));
}

class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Licenses')), body: ListView(padding: const EdgeInsets.all(16), children: const [
    OptionCard(child: ListTile(title: Text('GPL-3.0'), subtitle: Text('Dopamine, BaseBin and application code'))),
    OptionCard(child: ListTile(title: Text('BSD / MIT licenses'), subtitle: Text('Fugu15, ChOma, XPF, kfd and bundled libraries'))),
    OptionCard(child: ListTile(title: Text('BSD-2-Clause'), subtitle: Text('Procursus bootstrap packages'))),
  ]));
}



