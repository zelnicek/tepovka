import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/pages/qr_code_page.dart';
import 'package:tepovka/services/local_profile_service.dart';
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:tepovka/widgets/settings_widgets.dart';

/// The local profile: a form until one exists, then its QR code for the
/// doctor. Nothing here is an account; the profile never leaves the phone,
/// so the page says "profile", not "sign in". Laid out with the same cards
/// and rows as Settings.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);

  bool _busy = false;

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The button waits for a name instead of silently ignoring the tap.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameInput = _nameController.text.trim();
    final pin = _pinController.text.trim();
    if (nameInput.isEmpty) return;
    setState(() => _busy = true);
    await LocalProfileService.init();
    await LocalProfileService.signInLocal(
      name: nameInput,
      pin: pin.isEmpty ? null : pin,
    );
    if (mounted) setState(() => _busy = false);
  }

  /// Hides the profile after asking. The ID is kept, so a profile created
  /// again later shows the same QR code the doctor already knows.
  Future<void> _remove() async {
    final L10n t = L10n.of(context);
    if (!await confirmDestructive(
      context,
      title: t.profileRemoveTitle,
      body: t.profileRemoveBody,
      confirmLabel: t.profileRemoveConfirm,
    )) {
      return;
    }
    await LocalProfileService.signOutLocal();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t.profileRemoved),
      duration: const Duration(seconds: 2),
    ));
    setState(() {});
  }

  Future<void> _copyId(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10n.of(context).loginIdCopied),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          t.settingsMyProfile,
          style: TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            r.pagePadding.left, 0, r.pagePadding.right, r.spaceXl),
        children: LocalProfileService.isLoggedIn
            ? _profile(context, t)
            : _form(context, t),
      ),
    );
  }

  List<Widget> _form(BuildContext context, L10n t) {
    final r = Responsive.of(context);
    return [
      InfoSectionLabel(t.loginLocalProfile),
      SettingsCard(tint: SettingsTint.profile, children: [
        SettingsField(
          icon: Symbols.person,
          controller: _nameController,
          label: t.loginName,
          hint: t.loginNameHint,
          textInputAction: TextInputAction.next,
        ),
        SettingsField(
          icon: Symbols.pin,
          controller: _pinController,
          label: t.loginPin,
          hint: t.loginPinHint,
          keyboardType: TextInputType.number,
          obscureText: true,
          textInputAction: TextInputAction.done,
        ),
      ]),
      Padding(
        padding: EdgeInsets.fromLTRB(r.spaceXs, r.spaceSm, r.spaceXs, 0),
        child: Text(
          t.profileLocalHint,
          style: TextStyle(
              fontSize: r.fontSmall, color: kInfoSecondaryText, height: 1.4),
        ),
      ),
      SizedBox(height: r.spaceXl),
      SettingsPrimaryButton(
        icon: Symbols.person_add,
        label: t.profileCreate,
        busy: _busy,
        onPressed: _nameController.text.trim().isEmpty ? null : _save,
      ),
    ];
  }

  List<Widget> _profile(BuildContext context, L10n t) {
    final r = Responsive.of(context);
    final String uid = LocalProfileService.userId ?? '';
    final String name = LocalProfileService.displayName ?? '';
    final double qrSize =
        (MediaQuery.sizeOf(context).width * 0.6).clamp(180.0, 240.0);
    return [
      InfoSectionLabel(t.loginMyQr),
      InfoCard(
        padding: EdgeInsets.all(r.spaceXl),
        child: Column(
          children: [
            QrImageView(
              data: 'tepovka:local:$uid',
              version: QrVersions.auto,
              size: qrSize,
            ),
            SizedBox(height: r.spaceMd),
            Text(
              name.isNotEmpty ? name : t.settingsProfileUnnamed,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.spaceXs),
            Text(
              'ID ${uid.length > 6 ? '${uid.substring(0, 6)}…' : (uid.isEmpty ? '—' : uid)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: r.fontBody, color: kInfoSecondaryText),
            ),
            SizedBox(height: r.spaceMd),
            Text(
              t.loginQrHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: r.fontSmall,
                  color: kInfoSecondaryText,
                  height: 1.4),
            ),
          ],
        ),
      ),
      SizedBox(height: r.spaceLg),
      SettingsCard(tint: SettingsTint.profile, children: [
        SettingsRow(
          icon: Symbols.fullscreen,
          title: t.loginFullscreen,
          chevron: true,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const QrCodePage())),
        ),
        SettingsRow(
          icon: Symbols.content_copy,
          title: t.loginCopyId,
          onTap: () => _copyId(uid),
        ),
        SettingsRow(
          icon: Symbols.ios_share,
          title: t.loginShare,
          chevron: true,
          onTap: () =>
              SharePlus.instance.share(ShareParams(text: 'Tepovka ID: $uid')),
        ),
      ]),
      SizedBox(height: r.spaceLg),
      SettingsCard(children: [
        SettingsRow(
          icon: Symbols.person_remove,
          title: t.profileRemove,
          destructive: true,
          onTap: _remove,
        ),
      ]),
    ];
  }
}
