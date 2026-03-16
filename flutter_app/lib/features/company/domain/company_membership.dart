import '../../../core/firestore/models/company_member.dart';

class CompanyMembership {
  final String companyId;
  final CompanyMember member;

  const CompanyMembership({
    required this.companyId,
    required this.member,
  });
}
