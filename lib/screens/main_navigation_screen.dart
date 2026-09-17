import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/tv_mode_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tv_focusable.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'watchlist_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';
import 'manga_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isSidebarExpanded = true;

  void _navigateToHome() {
    setState(() => _currentIndex = 0);
  }

  bool _isDesktopLayout(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    return isDesktopPlatform || width >= 850;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tvMode = Provider.of<TvModeService>(context);
    final isTv = tvMode.isTvMode;
    final isDesktop = _isDesktopLayout(context) || isTv;

    // Lista de telas para o IndexedStack
    final List<Widget> screens = [
      const HomeScreen(),
      SearchScreen(onBackPressed: _navigateToHome),
      const WatchlistScreen(),
      const MangaScreen(),
      const DownloadsScreen(),
      SettingsScreen(onBackPressed: _navigateToHome),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: isDesktop
            ? Row(
                children: [
                  _buildDesktopSidebar(context, l10n, isTv: isTv),
                  Expanded(
                    child: Padding(
                      padding: tvMode.tvSafePadding,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: screens,
                      ),
                    ),
                  ),
                ],
              )
            : IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: isDesktop
            ? null
            : SafeArea(
                child: Container(
                  margin: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 12,
                  ),
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          icon: Ionicons.home_outline,
                          activeIcon: Ionicons.home,
                          label: l10n.home,
                          index: 0,
                        ),
                        _buildNavItem(
                          icon: Ionicons.search_outline,
                          activeIcon: Ionicons.search,
                          label: l10n.search,
                          index: 1,
                        ),
                        _buildNavItem(
                          icon: Ionicons.bookmark_outline,
                          activeIcon: Ionicons.bookmark,
                          label: l10n.watchlist,
                          index: 2,
                        ),
                        _buildNavItem(
                          icon: Ionicons.book_outline,
                          activeIcon: Ionicons.book,
                          label: 'Mangás',
                          index: 3,
                        ),
                        _buildNavItem(
                          icon: Ionicons.download_outline,
                          activeIcon: Ionicons.download,
                          label: l10n.downloads,
                          index: 4,
                        ),
                        _buildNavItem(
                          icon: Ionicons.settings_outline,
                          activeIcon: Ionicons.settings,
                          label: l10n.settings,
                          index: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Sidebar exclusiva para PC / TV / telas grandes
  Widget _buildDesktopSidebar(BuildContext context, AppLocalizations l10n, {bool isTv = false}) {
    final width = _isSidebarExpanded ? 240.0 : 78.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(
          right: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Cabeçalho da Sidebar (Logo + Título + Botão Toggle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.getPrimaryGradient(),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isTv ? Icons.tv_rounded : Icons.movie_filter_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isTv ? 'NekoCast TV' : 'NekoCast',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _isSidebarExpanded
                        ? Ionicons.chevron_back_outline
                        : Ionicons.chevron_forward_outline,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  tooltip: _isSidebarExpanded ? 'Recolher Menu' : 'Expandir Menu',
                  onPressed: () {
                    setState(() {
                      _isSidebarExpanded = !_isSidebarExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Itens do Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildSidebarItem(
                  icon: Ionicons.home_outline,
                  activeIcon: Ionicons.home,
                  label: l10n.home,
                  index: 0,
                  isTv: isTv,
                ),
                _buildSidebarItem(
                  icon: Ionicons.search_outline,
                  activeIcon: Ionicons.search,
                  label: l10n.search,
                  index: 1,
                  isTv: isTv,
                ),
                _buildSidebarItem(
                  icon: Ionicons.bookmark_outline,
                  activeIcon: Ionicons.bookmark,
                  label: l10n.watchlist,
                  index: 2,
                  isTv: isTv,
                ),
                _buildSidebarItem(
                  icon: Ionicons.book_outline,
                  activeIcon: Ionicons.book,
                  label: 'Mangás',
                  index: 3,
                  isTv: isTv,
                ),
                _buildSidebarItem(
                  icon: Ionicons.download_outline,
                  activeIcon: Ionicons.download,
                  label: l10n.downloads,
                  index: 4,
                  isTv: isTv,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _buildSidebarItem(
                  icon: Ionicons.settings_outline,
                  activeIcon: Ionicons.settings,
                  label: l10n.settings,
                  index: 5,
                  isTv: isTv,
                ),
              ],
            ),
          ),

          // Rodapé da Sidebar PC / TV
          if (_isSidebarExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTv ? Icons.tv_rounded : Ionicons.desktop_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTv ? 'NekoCast TV / Fire Stick' : 'NekoCast PC v1.0.4',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool isTv = false,
  }) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusable(
        onPressed: () => setState(() => _currentIndex = index),
        focusScale: 1.04,
        borderRadius: BorderRadius.circular(14),
        showFocusBorder: true,
        showFocusGlow: true,
        borderWidth: 2,
        focusBorderColor: AppColors.primary,
        builder: (context, hasFocus, isHovered) {
          final isHighlighted = isSelected || hasFocus;

          return Tooltip(
            message: _isSidebarExpanded ? '' : label,
            waitDuration: const Duration(milliseconds: 400),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarExpanded ? 14 : 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isHighlighted
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Icon(
                    isHighlighted ? activeIcon : icon,
                    color: isHighlighted ? AppColors.primary : AppColors.textSecondary,
                    size: 22,
                  ),
                  if (_isSidebarExpanded) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isHighlighted ? Colors.white : AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    fontSize: isSelected ? 10 : 9,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
