import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/showrooms/data/showrooms_repository.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'showrooms_controller.g.dart';

@riverpod
Future<List<Showroom>> showroomList(Ref ref) => ref.watch(showroomsRepositoryProvider).list();

@riverpod
Future<Showroom?> showroom(Ref ref, String id) => ref.watch(showroomsRepositoryProvider).get(id);

@riverpod
Future<ShowroomSettings> showroomSettings(Ref ref, String showroomId) =>
    ref.watch(showroomsRepositoryProvider).settings(showroomId);

@riverpod
Future<List<NumberingSeries>> numberingSeries(Ref ref, String showroomId) =>
    ref.watch(showroomsRepositoryProvider).series(showroomId);

@riverpod
Future<List<BankAccount>> bankAccounts(Ref ref, String showroomId) =>
    ref.watch(showroomsRepositoryProvider).bankAccounts(showroomId);

/// GST state list (reference data).
@Riverpod(keepAlive: true)
Future<List<IndianState>> indianStates(Ref ref) => ref.watch(showroomsRepositoryProvider).states();

/// Showroom commands. Changes that alter which showrooms the caller works in
/// (create, activate, deactivate) also reload the session, so the switcher
/// and the router follow at once.
@Riverpod(keepAlive: true)
ShowroomAdminActions showroomAdminActions(Ref ref) => ShowroomAdminActions(ref);

class ShowroomAdminActions {
  ShowroomAdminActions(this.ref);

  final Ref ref;

  ShowroomsRepository get repository => ref.read(showroomsRepositoryProvider);

  Future<String> create(Showroom showroom) async {
    final String id = await repository.create(showroom);
    ref.invalidate(showroomListProvider);
    await ref.read(sessionControllerProvider.notifier).refresh();
    return id;
  }

  Future<void> update(String id, Showroom showroom) async {
    await repository.update(id, showroom);
    ref
      ..invalidate(showroomProvider(id))
      ..invalidate(showroomListProvider)
      // The invoice prefix re-prefixes the numbering series.
      ..invalidate(numberingSeriesProvider(id));
    await ref.read(sessionControllerProvider.notifier).refresh();
  }

  Future<void> setActive(String id, {required bool active}) async {
    await repository.setActive(id, active: active);
    ref
      ..invalidate(showroomProvider(id))
      ..invalidate(showroomListProvider);
    await ref.read(sessionControllerProvider.notifier).refresh();
  }

  Future<void> updateSettings(ShowroomSettings settings) async {
    await repository.updateSettings(settings);
    ref.invalidate(showroomSettingsProvider(settings.showroomId));
  }

  Future<void> saveBankAccount(BankAccount account) async {
    await repository.saveBankAccount(account);
    ref.invalidate(bankAccountsProvider(account.showroomId));
  }

  Future<void> deleteBankAccount(BankAccount account) async {
    await repository.deleteBankAccount(account.id!);
    ref.invalidate(bankAccountsProvider(account.showroomId));
  }
}
