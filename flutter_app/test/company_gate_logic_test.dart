import 'package:flutter_app/core/firestore/models/company_member.dart';
import 'package:flutter_app/features/company/domain/company_gate_logic.dart';
import 'package:flutter_app/features/company/domain/company_membership.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1 active membership => auto select companyId', () {
    final decision = decideCompanyGate(
      memberships: [
        CompanyMembership(
          companyId: 'c1',
          member: const CompanyMember(
            uid: 'u1',
            role: 'member',
            status: 'active',
            permissions: <String>[],
            storeIds: <String>[],
          ),
        ),
      ],
      currentActiveCompanyId: null,
    );

    expect(decision.route, CompanyGateRoute.ready);
    expect(decision.autoSelectCompanyId, 'c1');
  });

  test('pending membership (no active) => pending screen', () {
    final decision = decideCompanyGate(
      memberships: [
        CompanyMembership(
          companyId: 'c1',
          member: const CompanyMember(
            uid: 'u1',
            role: 'member',
            status: 'pending',
            permissions: <String>[],
            storeIds: <String>[],
          ),
        ),
      ],
      currentActiveCompanyId: null,
    );

    expect(decision.route, CompanyGateRoute.pendingApproval);
    expect(decision.autoSelectCompanyId, isNull);
  });

  test('no memberships => no company screen', () {
    final decision = decideCompanyGate(
      memberships: const <CompanyMembership>[],
      currentActiveCompanyId: null,
    );

    expect(decision.route, CompanyGateRoute.noCompany);
  });
}
