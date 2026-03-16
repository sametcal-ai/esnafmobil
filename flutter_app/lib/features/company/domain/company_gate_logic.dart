import 'company_membership.dart';

enum CompanyGateRoute {
  loading,
  ready,
  pendingApproval,
  selectCompany,
  noCompany,
}

class CompanyGateDecision {
  final CompanyGateRoute route;
  final String? autoSelectCompanyId;
  final List<String> activeCompanyIds;

  const CompanyGateDecision({
    required this.route,
    required this.autoSelectCompanyId,
    required this.activeCompanyIds,
  });
}

CompanyGateDecision decideCompanyGate({
  required List<CompanyMembership> memberships,
  required String? currentActiveCompanyId,
}) {
  final active = memberships
      .where((m) => m.member.status == 'active')
      .map((m) => m.companyId)
      .toList(growable: false);

  final pending = memberships.where((m) => m.member.status == 'pending');

  if (currentActiveCompanyId != null && active.contains(currentActiveCompanyId)) {
    return CompanyGateDecision(
      route: CompanyGateRoute.ready,
      autoSelectCompanyId: null,
      activeCompanyIds: active,
    );
  }

  if (active.length == 1) {
    return CompanyGateDecision(
      route: CompanyGateRoute.ready,
      autoSelectCompanyId: active.first,
      activeCompanyIds: active,
    );
  }

  if (active.length > 1) {
    return CompanyGateDecision(
      route: CompanyGateRoute.selectCompany,
      autoSelectCompanyId: null,
      activeCompanyIds: active,
    );
  }

  if (pending.isNotEmpty) {
    return const CompanyGateDecision(
      route: CompanyGateRoute.pendingApproval,
      autoSelectCompanyId: null,
      activeCompanyIds: <String>[],
    );
  }

  return const CompanyGateDecision(
    route: CompanyGateRoute.noCompany,
    autoSelectCompanyId: null,
    activeCompanyIds: <String>[],
  );
}
