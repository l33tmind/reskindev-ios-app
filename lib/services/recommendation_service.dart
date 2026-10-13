import 'dart:math' as math;
import '../models/gig_model.dart';

/// Why a gig was recommended, shown as a tiny caption on the card.
class Recommendation {
  final GigModel gig;
  final String reason;
  const Recommendation(this.gig, this.reason);
}

/// "Recommended for You": gigs this buyer hasn't looked at yet that match what they care about,
/// ranked by how good they actually are.
///
/// Interest profile (what the buyer likes):
///  - gigs they saved   (strongest signal)
///  - gigs they ordered (strong)
///  - gigs they viewed  (weaker, newest counts more)
/// Each gig gives its category and keywords some weight.
///
/// Score of a candidate gig (0..1):
///  - 45% relevance : same category / shared keywords as the buyer's interests
///  - 35% quality   : rating, but trusted only as much as there are reviews (Bayesian average),
///                    so one 5-star review does not beat 40 reviews at 4.9
///  - 10% trust     : more reviews = more proven
///  - 10% price fit : close to what the buyer usually looks at
/// Not recommended: your own gigs, gigs on vacation, gigs already ordered. Gigs already viewed/saved only
/// appear (as "Top rated") when there are fewer than 4 new ones to show.
class RecommendationService {
  static double _price(GigModel g) => g.packages.isNotEmpty ? g.packages.first.price : g.basePrice;

  static List<Recommendation> recommend({
    required List<GigModel> allGigs,
    required List<String> recentIds, // newest first
    required Set<String> savedIds,
    required Set<String> orderedIds,
    String? myUid,
    int limit = 10,
  }) {
    final byId = {for (final g in allGigs) g.id: g};
    final candidates = allGigs.where((g) => g.authorId != myUid && !g.isVacation).toList();
    if (candidates.isEmpty) return const [];

    // ── Quality: Bayesian average rating ──
    final rated = allGigs.where((g) => g.reviewCount > 0).toList();
    final globalMean = rated.isEmpty ? 4.5 : rated.map((g) => g.averageRating).reduce((a, b) => a + b) / rated.length;
    const minReviews = 3.0; // how many reviews before the gig's own rating is mostly trusted
    double quality(GigModel g) {
      final v = g.reviewCount.toDouble();
      final bayes = (v * g.averageRating + minReviews * globalMean) / (v + minReviews);
      return (bayes / 5.0).clamp(0.0, 1.0);
    }

    // ── Interest profile ──
    final categoryWeight = <String, double>{};
    final keywordWeight = <String, double>{};
    final interestPrices = <double>[];
    void learn(GigModel g, double w) {
      if (g.category.isNotEmpty) {
        categoryWeight[g.category.toLowerCase()] = (categoryWeight[g.category.toLowerCase()] ?? 0) + w;
      }
      for (final k in g.keywords) {
        final key = k.toLowerCase().trim();
        if (key.isNotEmpty) keywordWeight[key] = (keywordWeight[key] ?? 0) + w;
      }
      interestPrices.add(_price(g));
    }

    for (final id in savedIds) {
      final g = byId[id];
      if (g != null) learn(g, 3.0);
    }
    for (final id in orderedIds) {
      final g = byId[id];
      if (g != null) learn(g, 2.0);
    }
    for (var i = 0; i < recentIds.length; i++) {
      final g = byId[recentIds[i]];
      if (g != null) learn(g, 1.5 * math.pow(0.85, i)); // newest views count most
    }

    final seen = {...recentIds, ...savedIds, ...orderedIds};
    final hasProfile = categoryWeight.isNotEmpty || keywordWeight.isNotEmpty;

    final maxCategory = categoryWeight.values.isEmpty ? 1.0 : categoryWeight.values.reduce(math.max);
    final maxKeywordHits = keywordWeight.values.isEmpty ? 1.0 : keywordWeight.values.fold<double>(0, (a, b) => a + b);

    double? medianPrice;
    if (interestPrices.isNotEmpty) {
      final sorted = [...interestPrices]..sort();
      medianPrice = sorted[sorted.length ~/ 2];
    }
    final maxReviews = candidates.map((g) => g.reviewCount).fold<int>(1, math.max);

    final scored = <_Scored>[];
    final topUp = <_Scored>[]; // already viewed/saved gigs, only used to fill a thin row
    for (final g in candidates) {
      if (orderedIds.contains(g.id)) continue; // never recommend what they already bought

      final cat = categoryWeight[g.category.toLowerCase()] ?? 0;
      var kw = 0.0;
      for (final k in g.keywords) {
        kw += keywordWeight[k.toLowerCase().trim()] ?? 0;
      }
      final relevance = hasProfile
          ? (0.7 * (cat / maxCategory) + 0.3 * (kw / maxKeywordHits).clamp(0.0, 1.0)).clamp(0.0, 1.0)
          : 0.0;

      final trust = math.log(1 + g.reviewCount) / math.log(1 + maxReviews);

      var priceFit = 0.5;
      if (medianPrice != null && medianPrice > 0 && _price(g) > 0) {
        final ratio = _price(g) / medianPrice;
        priceFit = (1 - (math.log(ratio).abs() / math.log(4))).clamp(0.0, 1.0); // within ~4x is fine
      }

      final score = hasProfile
          ? 0.45 * relevance + 0.35 * quality(g) + 0.10 * trust + 0.10 * priceFit
          : 0.70 * quality(g) + 0.30 * trust; // new buyer: simply the best proven gigs

      final reason = !hasProfile
          ? 'Top rated'
          : (cat > 0 ? 'More in ${g.category}' : (kw > 0 ? 'Like your picks' : 'Top rated'));
      if (seen.contains(g.id)) {
        topUp.add(_Scored(g, quality(g) + 0.3 * trust, 'Top rated'));
      } else {
        scored.add(_Scored(g, score, reason));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Keep a mix: no more than 2 gigs from the same seller in the row
    final perSeller = <String, int>{};
    final out = <Recommendation>[];
    for (final s in scored) {
      final count = perSeller[s.gig.authorId] ?? 0;
      if (count >= 2) continue;
      perSeller[s.gig.authorId] = count + 1;
      out.add(Recommendation(s.gig, s.reason));
      if (out.length >= limit) break;
    }

    // A buyer who has already looked at most gigs would get an empty row: top it up with the best rated ones
    if (out.length < 4) {
      topUp.sort((a, b) => b.score.compareTo(a.score));
      for (final s in topUp) {
        if (out.length >= 4) break;
        out.add(Recommendation(s.gig, s.reason));
      }
    }
    return out;
  }
}

class _Scored {
  final GigModel gig;
  final double score;
  final String reason;
  _Scored(this.gig, this.score, this.reason);
}
