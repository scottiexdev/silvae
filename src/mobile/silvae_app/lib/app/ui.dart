import 'package:flutter/material.dart';
import 'package:silvae_app/app/theme.dart';

/// Il significato di uno stato, non il suo colore: chi scrive una schermata
/// dice «attenzione», il tema decide che tinta abbia di giorno e di notte.
enum Tone { neutral, info, positive, caution, danger }

typedef ToneColors = ({Color foreground, Color background});

ToneColors toneColors(BuildContext context, Tone tone) {
  final colors = Theme.of(context).colorScheme;
  final dark = colors.brightness == Brightness.dark;
  return switch (tone) {
    Tone.neutral => (
      foreground: colors.onSurfaceVariant,
      background: colors.surfaceContainerHigh,
    ),
    Tone.info =>
      dark
          ? (
              foreground: const Color(0xFFA9CDE2),
              background: const Color(0xFF1C3140),
            )
          : (
              foreground: const Color(0xFF1F5673),
              background: const Color(0xFFDCEAF2),
            ),
    Tone.positive =>
      dark
          ? (
              foreground: const Color(0xFF9BD2AF),
              background: const Color(0xFF1E4030),
            )
          : (
              foreground: const Color(0xFF2A6B47),
              background: const Color(0xFFD8EBDF),
            ),
    Tone.caution =>
      dark
          ? (
              foreground: const Color(0xFFE4C68F),
              background: const Color(0xFF40331A),
            )
          : (
              foreground: const Color(0xFF7A5210),
              background: const Color(0xFFF6E7C8),
            ),
    Tone.danger => (
      foreground: colors.error,
      background: colors.errorContainer,
    ),
  };
}

/// Un'etichetta di stato: quadrata, piccola, leggibile di sbieco con il
/// telefono in mano e i guanti addosso.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tint.foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tint.foreground),
          ),
        ],
      ),
    );
  }
}

/// L'icona dentro un quadrato tinto: dà un punto d'appoggio all'occhio in una
/// lista lunga, dove i titoli si somigliano tutti.
class IconBadge extends StatelessWidget {
  const IconBadge({
    required this.icon,
    this.tone = Tone.neutral,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = toneColors(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Icon(icon, size: size * .5, color: tint.foreground),
    );
  }
}

/// La scheda su cui poggia quasi tutto: bordo sottile invece dell'ombra, e
/// una reazione al passaggio e alla pressione, così si capisce cosa si tocca.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Una banda verticale sul bordo: serve quando la scheda chiede qualcosa,
  /// come un conflitto da risolvere.
  final Color? accent;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final interactive = widget.onTap != null;
    final border = _hovered && interactive
        ? colors.primary.withValues(alpha: .55)
        : colors.outlineVariant;

    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: _hovered && interactive
              ? [
                  BoxShadow(
                    // L'ombra prende il colore della pagina invece del nero:
                    // un nero puro su carta calda si vede subito che è finto.
                    color: colors.shadow.withValues(alpha: .07),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: cardSurface(colors),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: BorderSide(color: border),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hovered = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            // La banda sta in uno Stack e non in una Row: dentro una lista
            // l'altezza non è ancora nota, e un figlio «stirato» in una Row
            // chiederebbe di essere alto infinito.
            child: Stack(
              children: [
                Padding(
                  padding: widget.accent == null
                      ? widget.padding
                      : widget.padding.add(const EdgeInsets.only(left: 4)),
                  child: widget.child,
                ),
                if (widget.accent != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: ColoredBox(color: widget.accent!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// L'intestazione di una sezione: titolo, un dato di sintesi a destra e
/// l'azione che la riguarda.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onAdd,
    this.addTooltip = 'Aggiungi',
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          ?trailing,
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton.filledTonal(
                tooltip: addTooltip,
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

/// I dati minuti di una riga — data, ore, quante persone — messi in fila con
/// la loro icona invece che incollati in un unico testo a capo.
class Facts extends StatelessWidget {
  const Facts(this.items, {super.key});

  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.tabular;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.$1,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(item.$2, style: style),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Una spiegazione che accompagna la schermata senza fingersi un dato.
class InfoNote extends StatelessWidget {
  const InfoNote(this.message, {this.icon = Icons.info_outline, super.key});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una lista vuota non è un errore: è un punto di partenza, e va detto cosa
/// farci.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, size: 56),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// L'errore detto in italiano, con il dettaglio tecnico sotto per chi lo deve
/// riferire.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.title, required this.detail, super.key});

  final String title;
  final Object detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = toneColors(context, Tone.danger);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(
            icon: Icons.cloud_off_outlined,
            tone: Tone.danger,
            size: 56,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tint.background,
                borderRadius: BorderRadius.circular(Radii.field),
              ),
              child: SelectableText(
                '$detail',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tint.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'attesa con la forma di quello che sta arrivando: una lista che pulsa
/// dice più di una rotellina al centro dello schermo.
class LoadingList extends StatefulWidget {
  const LoadingList({this.rows = 4, super.key});

  final int rows;

  @override
  State<LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: .45, end: .9).animate(_pulse),
      child: Column(
        children: List.generate(
          widget.rows,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: Insets.gap),
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il corpo di una schermata: su un monitor il contenuto smette di allargarsi
/// dove il testo diventa illeggibile, invece di correre da bordo a bordo.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(
      Insets.gutter,
      Insets.gutter,
      Insets.gutter,
      Insets.bottom,
    ),
    this.controller,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: ListView(
          controller: controller,
          padding: padding,
          // Anche una lista corta deve poter essere tirata giù: è il gesto con
          // cui si chiede di risincronizzare.
          physics: const AlwaysScrollableScrollPhysics(),
          children: children,
        ),
      ),
    );
  }
}

/// Lo spazio fra due schede di una lista.
const SizedBox gapCards = SizedBox(height: Insets.gap);

/// Lo stacco fra due sezioni di una stessa schermata.
const SizedBox gapSections = SizedBox(height: Insets.section);

/// Il marchio: il quadrato con l'albero e il nome accanto. Sta in cima
/// all'accesso e nella barra dell'app, sempre uguale.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 40, this.showName = true, super.key});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(size * .3),
          ),
          child: Icon(
            Icons.forest,
            size: size * .56,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        if (showName) ...[
          SizedBox(width: size * .3),
          Text(
            'Silvae',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: size * .52,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// La riga delle linguette, appoggiata sulla stessa carta della barra
/// dell'app e chiusa da un filo: senza, sembra che galleggi sul contenuto.
class TabStrip extends StatelessWidget {
  const TabStrip(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: labels.map((label) => Tab(text: label)).toList(growable: false),
      ),
    );
  }
}
