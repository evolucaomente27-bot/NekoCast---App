import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/doh_service.dart';
import '../services/locale_service.dart';
import '../services/player_service.dart';
import '../services/tv_mode_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const SettingsScreen({super.key, this.onBackPressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nextDnsController;
  late TextEditingController _customDohController;
  bool _isTestingDoh = false;
  DohTestResult? _dohTestResult;

  @override
  void initState() {
    super.initState();
    final dohService = Provider.of<DohService>(context, listen: false);
    _nextDnsController = TextEditingController(text: dohService.nextDnsProfileId);
    _customDohController = TextEditingController(text: dohService.customEndpoint);
  }

  @override
  void dispose() {
    _nextDnsController.dispose();
    _customDohController.dispose();
    super.dispose();
  }

  Future<void> _runDohTest(DohService dohService) async {
    setState(() {
      _isTestingDoh = true;
      _dohTestResult = null;
    });

    final result = await dohService.testResolution();

    if (mounted) {
      setState(() {
        _isTestingDoh = false;
        _dohTestResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeService = Provider.of<LocaleService>(context);
    final playerService = Provider.of<PlayerService>(context);
    final dohService = Provider.of<DohService>(context);
    final tvModeService = Provider.of<TvModeService>(context);
    final isPt = localeService.isPortuguese;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NekoCast',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          onPressed: () {
            if (canPop) {
              Navigator.pop(context);
            } else if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Reprodutor de Vídeo ──────────────────────────────────────────
          _buildSectionCard(
            title: l10n.videoPlayer,
            icon: Icons.play_circle_outline_rounded,
            iconColor: AppColors.primary,
            child: Column(
              children: [
                _buildPlayerEngineTile(
                  title: 'Neko Native Player',
                  subtitle: isPt
                      ? 'MediaKit / MPV • Aceleração GPU DirectX (Recomendado para Windows / Desktop)'
                      : 'MediaKit / MPV • DirectX GPU Acceleration (Recommended for Windows / Desktop)',
                  badge: 'MPV',
                  isSelected: playerService.isMediaKit,
                  onTap: () async {
                    await playerService.setEngine(PlayerEngine.mediaKit);
                    if (context.mounted) {
                      _showSnackBar(context, l10n.playerEngineChanged);
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildPlayerEngineTile(
                  title: 'BetterPlayer',
                  subtitle: isPt
                      ? 'Reprodutor nativo mobile para Android e iOS'
                      : 'Native mobile player for Android & iOS',
                  badge: 'BP',
                  isSelected: playerService.isBetterPlayer,
                  onTap: () async {
                    await playerService.setEngine(PlayerEngine.betterPlayer);
                    if (context.mounted) {
                      _showSnackBar(context, l10n.playerEngineChanged);
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildPlayerEngineTile(
                  title: isPt ? 'Player Externo' : 'External Player',
                  subtitle: isPt
                      ? 'Abrir streams diretamente em apps externos (VLC, MPC-HC, etc)'
                      : 'Open streams in external apps (VLC, MPC-HC, etc)',
                  badge: 'EXT',
                  isSelected: playerService.isExternalApp,
                  onTap: () async {
                    await playerService.setEngine(PlayerEngine.externalApp);
                    if (context.mounted) {
                      _showSnackBar(context, l10n.playerEngineChanged);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Preferência de Áudio (Dublado / Legendado) ───────────────────────
          _buildSectionCard(
            title: isPt ? 'Preferência de Áudio' : 'Audio Preference',
            icon: Icons.record_voice_over_rounded,
            iconColor: const Color(0xFF4CAF50),
            child: Column(
              children: [
                _buildAudioPreferenceTile(
                  title: isPt
                      ? 'Dublado (Português PT-BR)'
                      : 'Dubbed (Portuguese PT-BR)',
                  subtitle: isPt
                      ? 'Prioriza automaticamente a versão com áudio dublado em português quando disponível.'
                      : 'Automatically prioritizes the dubbed audio track in Portuguese when available.',
                  flag: '🇧🇷',
                  isSelected: playerService.isDubbedPreferred,
                  onTap: () async {
                    await playerService
                        .setPreferredAudio(PreferredAudio.dubbed);
                    if (context.mounted) {
                      _showSnackBar(
                        context,
                        isPt
                            ? 'Preferência de áudio definida para Dublado (PT-BR)'
                            : 'Audio preference set to Dubbed (PT-BR)',
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildAudioPreferenceTile(
                  title: isPt
                      ? 'Legendado (Áudio Original)'
                      : 'Subbed (Original Audio)',
                  subtitle: isPt
                      ? 'Prioriza a versão original com legendas em português.'
                      : 'Prioritizes original audio track with subtitles.',
                  flag: '🇯🇵',
                  isSelected: !playerService.isDubbedPreferred,
                  onTap: () async {
                    await playerService
                        .setPreferredAudio(PreferredAudio.subbed);
                    if (context.mounted) {
                      _showSnackBar(
                        context,
                        isPt
                            ? 'Preferência de áudio definida para Legendado'
                            : 'Audio preference set to Subbed',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Modo TV & Fire Stick ──────────────────────────────────────────
          _buildSectionCard(
            title: isPt ? 'Modo TV & Fire Stick' : 'TV & Fire Stick Mode',
            icon: Icons.tv_rounded,
            iconColor: const Color(0xFFFF9E00),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text(
                    isPt ? 'Interface Otimizada para TV' : 'TV Optimized Interface',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isPt
                        ? 'Ativa barra lateral Leanback, navegação por controle remoto (D-Pad), cards ampliados e controles de player dedicados.'
                        : 'Enables Leanback sidebar, D-Pad remote navigation, enlarged cards and remote controls.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: tvModeService.isTvMode,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    await tvModeService.setTvMode(val);
                    if (context.mounted) {
                      _showSnackBar(
                        context,
                        val
                            ? (isPt ? 'Modo TV ativado' : 'TV Mode enabled')
                            : (isPt ? 'Modo TV desativado' : 'TV Mode disabled'),
                      );
                    }
                  },
                ),
                if (tvModeService.isTvMode) ...[
                  const Divider(height: 1, color: Colors.white12),
                  SwitchListTile(
                    title: Text(
                      isPt ? 'Margem de TV Segura (Overscan)' : 'TV Safe Margins (Overscan)',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isPt
                          ? 'Adiciona recuo nas bordas para aparelhos e televisores que cortam as extremidades da tela.'
                          : 'Adds edge padding for TVs that cut off screen edges.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: tvModeService.overscanCompensation,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      await tvModeService.setOverscanCompensation(val);
                    },
                  ),
                ],
                const Divider(height: 1, color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        tvModeService.isAutoDetectedTv
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        color: tvModeService.isAutoDetectedTv
                            ? Colors.greenAccent
                            : AppColors.textTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tvModeService.isAutoDetectedTv
                              ? (isPt
                                  ? 'Dispositivo reconhecido nativamente como Android TV / Fire Stick.'
                                  : 'Device recognized natively as Android TV / Fire Stick.')
                              : (isPt
                                  ? 'Dispositivo móvel ou desktop (Modo TV pode ser alternado manualmente acima).'
                                  : 'Mobile or desktop device (TV mode can be toggled manually above).'),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Segurança & DNS-over-HTTPS (NextDNS) ───────────────────────────
          _buildSectionCard(
            title: l10n.dohSecurity,
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF00B4D8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    l10n.dohDescription,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    l10n.enableDoh,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    dohService.isEnabled
                        ? 'Ativo • Tráfego HTTPS criptografado com ${dohService.providerDisplayName}'
                        : 'Desativado • Usando DNS padrão do sistema',
                    style: TextStyle(
                      color: dohService.isEnabled ? const Color(0xFF48CAE4) : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: dohService.isEnabled,
                  onChanged: (val) => dohService.setEnabled(val),
                ),
                if (dohService.isEnabled) ...[
                  const Divider(height: 1, color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      l10n.dohProvider,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _buildDohProviderTile(
                    title: 'NextDNS (Recomendado)',
                    subtitle: 'Proteção contra rastreadores, anúncios e bloqueios com suporte a perfil pessoal',
                    badge: 'NEXT',
                    isSelected: dohService.provider == DohProvider.nextDns,
                    onTap: () => dohService.setProvider(DohProvider.nextDns),
                  ),
                  if (dohService.provider == DohProvider.nextDns)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.nextDnsProfile,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nextDnsController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: l10n.nextDnsProfileHint,
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.black45,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.check, color: AppColors.primary, size: 18),
                                  tooltip: 'Salvar ID',
                                  onPressed: () {
                                    dohService.setNextDnsProfileId(_nextDnsController.text);
                                    _showSnackBar(context, 'ID do NextDNS atualizado!');
                                  },
                                ),
                              ),
                              onSubmitted: (val) {
                                dohService.setNextDnsProfileId(val);
                                _showSnackBar(context, 'ID do NextDNS atualizado!');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 1, color: Colors.white12),
                  _buildDohProviderTile(
                    title: 'Cloudflare DNS',
                    subtitle: '1.1.1.1 • Alta velocidade e privacidade mundial',
                    badge: '1.1.1.1',
                    isSelected: dohService.provider == DohProvider.cloudflare,
                    onTap: () => dohService.setProvider(DohProvider.cloudflare),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _buildDohProviderTile(
                    title: 'Google Public DNS',
                    subtitle: '8.8.8.8 • Resolução global rápida e estável',
                    badge: '8.8.8.8',
                    isSelected: dohService.provider == DohProvider.google,
                    onTap: () => dohService.setProvider(DohProvider.google),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _buildDohProviderTile(
                    title: 'AdGuard DNS',
                    subtitle: 'Bloqueio integrado de anúncios e rastreadores',
                    badge: 'ADG',
                    isSelected: dohService.provider == DohProvider.adguard,
                    onTap: () => dohService.setProvider(DohProvider.adguard),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _buildDohProviderTile(
                    title: 'DoH Customizado',
                    subtitle: 'Insira sua própria URL de endpoint DoH',
                    badge: 'CUST',
                    isSelected: dohService.provider == DohProvider.custom,
                    onTap: () => dohService.setProvider(DohProvider.custom),
                  ),
                  if (dohService.provider == DohProvider.custom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: TextField(
                        controller: _customDohController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'https://seu-servidor-doh.com/dns-query',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.black45,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check, color: AppColors.primary, size: 18),
                            onPressed: () {
                              dohService.setCustomEndpoint(_customDohController.text);
                              _showSnackBar(context, 'Endpoint DoH salvo!');
                            },
                          ),
                        ),
                        onSubmitted: (val) {
                          dohService.setCustomEndpoint(val);
                          _showSnackBar(context, 'Endpoint DoH salvo!');
                        },
                      ),
                    ),

                  // ── Teste de Conexão DoH ──
                  const Divider(height: 1, color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _dohTestResult != null
                              ? (_dohTestResult!.success ? Colors.green.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.4))
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _dohTestResult != null
                                        ? (_dohTestResult!.success ? Icons.check_circle_rounded : Icons.error_outline_rounded)
                                        : Icons.speed_rounded,
                                    color: _dohTestResult != null
                                        ? (_dohTestResult!.success ? Colors.greenAccent : Colors.redAccent)
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Diagnóstico DoH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _isTestingDoh ? null : () => _runDohTest(dohService),
                                icon: _isTestingDoh
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.play_arrow_rounded, size: 16),
                                label: Text(
                                  _isTestingDoh ? l10n.dohTesting : l10n.testDohConnection,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_dohTestResult != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _dohTestResult!.success
                                  ? '✅ ${_dohTestResult!.providerName} funcionando com sucesso!\n• Latência: ${_dohTestResult!.latencyMs}ms\n• IP Resolvido: ${_dohTestResult!.resolvedIp}'
                                  : '❌ Falha ao resolver via ${_dohTestResult!.providerName}:\n${_dohTestResult!.error}',
                              style: TextStyle(
                                color: _dohTestResult!.success ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Idioma ────────────────────────────────────────────────────────
          _buildSectionCard(
            title: l10n.language,
            icon: Icons.language,
            iconColor: AppColors.accent,
            child: Column(
              children: [
                _buildLanguageTile(
                  title: l10n.english,
                  subtitle: 'English (US)',
                  badge: 'EN',
                  isSelected: localeService.isEnglish,
                  onTap: () async {
                    await localeService.setEnglish();
                    if (context.mounted) {
                      _showSnackBar(context, l10n.languageChanged);
                    }
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildLanguageTile(
                  title: l10n.portuguese,
                  subtitle: 'Português (Brasil)',
                  badge: 'PT',
                  isSelected: localeService.isPortuguese,
                  onTap: () async {
                    await localeService.setPortuguese();
                    if (context.mounted) {
                      _showSnackBar(context, l10n.languageChanged);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Sobre ─────────────────────────────────────────────────────────
          _buildSectionCard(
            title: l10n.about,
            icon: Icons.info_outline,
            iconColor: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceLight,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const BrandLogo(height: 128),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NekoCast',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      'Seu streaming de anime com identidade própria',
                      style: TextStyle(
                        color: AppColors.accentLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${l10n.version} 0.0.2',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Interface retrabalhada com suporte nativo a Windows (libmpv), DoH NextDNS, navegação refinada e branding exclusivo.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String subtitle,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerEngineTile({
    required String title,
    required String subtitle,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? AppColors.getPrimaryGradient()
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : Colors.white10,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPreferenceTile({
    required String title,
    required String subtitle,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF66BB6A)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                flag,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDohProviderTile({
    required String title,
    required String subtitle,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00B4D8).withValues(alpha: 0.6)
                      : Colors.white10,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4D8).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF90E0EF),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}


