import 'package:mybike_showroom/features/showrooms/data/showrooms_repository.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';

const Showroom indore = Showroom(
  id: 's-ind',
  code: 'INDORE-MAIN',
  name: 'Indore Main',
  invoicePrefix: 'IND',
  legalName: 'MyBike Motors Private Limited',
  gstin: '23ABCDE1234F1Z5',
  pan: 'ABCDE1234F',
  city: 'Indore',
  stateCode: '23',
);

const ShowroomSettings indoreSettings = ShowroomSettings(
  showroomId: 's-ind',
  gstEnabled: true,
  roundOffEnabled: true,
  postCogsOnSale: true,
  allowNegativeStock: false,
  valuationMethod: 'specific_id',
  lowStockThreshold: 5,
  bookingMinAmount: '5000.50',
  bookingValidityDays: 30,
  invoiceTerms: 'Goods once sold will not be taken back.',
);

/// In-memory [ShowroomsRepository]: canned reads, recorded writes.
final class FakeShowroomsRepository implements ShowroomsRepository {
  FakeShowroomsRepository({List<Showroom>? showrooms, List<BankAccount>? accounts})
      : showrooms = showrooms ?? <Showroom>[indore],
        accounts = accounts ?? <BankAccount>[];

  List<Showroom> showrooms;
  List<BankAccount> accounts;
  final List<String> calls = <String>[];
  Showroom? created;
  BankAccount? savedAccount;

  @override
  Future<List<Showroom>> list() async => showrooms;

  @override
  Future<Showroom?> get(String id) async {
    for (final Showroom s in showrooms) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<ShowroomSettings> settings(String showroomId) async => indoreSettings;

  @override
  Future<List<NumberingSeries>> series(String showroomId) async => const <NumberingSeries>[
        NumberingSeries(docType: 'sales_invoice', prefix: 'IND', nextNumber: 1, padding: 5, financialYear: '2026-27'),
      ];

  @override
  Future<List<BankAccount>> bankAccounts(String showroomId) async => accounts;

  @override
  Future<List<IndianState>> states() async => const <IndianState>[
        IndianState(code: '23', name: 'Madhya Pradesh'),
        IndianState(code: '27', name: 'Maharashtra'),
      ];

  @override
  Future<String> create(Showroom showroom) async {
    created = showroom;
    calls.add('create ${showroom.toJson()['code']}');
    return 's-new';
  }

  @override
  Future<void> update(String id, Showroom showroom) async => calls.add('update $id');

  @override
  Future<void> setActive(String id, {required bool active}) async => calls.add('setActive $id $active');

  @override
  Future<void> updateSettings(ShowroomSettings settings) async => calls.add('updateSettings ${settings.showroomId}');

  @override
  Future<void> saveBankAccount(BankAccount account) async {
    savedAccount = account;
    calls.add('saveBankAccount ${account.toJson()['ifsc']}');
  }

  @override
  Future<void> deleteBankAccount(String id) async => calls.add('deleteBankAccount $id');
}
