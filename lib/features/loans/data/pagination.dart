/// Exactly `Pagination` in `openapi.yaml` — the same envelope shape
/// `GET /client/prestamos` and `GET /admin/prestamos` both return. `total` is
/// the row count across every page, not just the current one; `totalPages`
/// is `0` only when `total` is `0` (confirmed against
/// `services/prestamoService.js#construirPaginacion`), never negative or
/// omitted.
class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    final page = json['page'];
    final limit = json['limit'];
    final total = json['total'];
    final totalPages = json['totalPages'];
    if (page is! int || limit is! int || total is! int || totalPages is! int) {
      throw const FormatException('Paginación con forma inesperada.');
    }
    return Pagination(
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }
}
