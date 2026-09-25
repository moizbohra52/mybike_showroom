import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Showrooms, their settings, numbering and bank accounts. RLS decides every
/// read and write (showrooms.edit in the showroom; creating needs
/// showrooms.create granted globally, via rpc_create_showroom).
abstract interface class ShowroomsRepository {
  /// Showrooms the caller can access (Super Admin: also inactive ones).
  Future<List<Showroom>> list();

  /// `null` when not visible.
  Future<Showroom?> get(String id);
  Future<ShowroomSettings> settings(String showroomId);
  Future<List<NumberingSeries>> series(String showroomId);
  Future<List<BankAccount>> bankAccounts(String showroomId);
  Future<List<IndianState>> states();

  /// Returns the new showroom id.
  Future<String> create(Showroom showroom);
  Future<void> update(String id, Showroom showroom);
  Future<void> setActive(String id, {required bool active});
  Future<void> updateSettings(ShowroomSettings settings);
  Future<void> saveBankAccount(BankAccount account);
  Future<void> deleteBankAccount(String id);
}

final class SupabaseShowroomsRepository implements ShowroomsRepository {
  SupabaseShowroomsRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<Showroom>> list() {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client.from('showrooms').select(Showroom.columns).order('code');
      return <Showroom>[for (final Map<String, dynamic> row in rows) Showroom.fromJson(row)];
    });
  }

  @override
  Future<Showroom?> get(String id) {
    return ErrorMapper.guard(() async {
      final Map<String, dynamic>? row = await client.from('showrooms').select(Showroom.columns).eq('id', id).maybeSingle();
      return row == null ? null : Showroom.fromJson(row);
    });
  }

  @override
  Future<ShowroomSettings> settings(String showroomId) {
    return ErrorMapper.guard(() async {
      final Map<String, dynamic> row =
          await client.from('showroom_settings').select(ShowroomSettings.columns).eq('showroom_id', showroomId).single();
      return ShowroomSettings.fromJson(row);
    });
  }

  @override
  Future<List<NumberingSeries>> series(String showroomId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('document_sequences')
          .select('doc_type, prefix, suffix, next_number, padding, financial_years!inner(code, is_closed)')
          .eq('showroom_id', showroomId)
          .eq('financial_years.is_closed', false)
          .order('doc_type');
      return <NumberingSeries>[for (final Map<String, dynamic> row in rows) NumberingSeries.fromJson(row)];
    });
  }

  @override
  Future<List<BankAccount>> bankAccounts(String showroomId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('bank_accounts')
          .select(BankAccount.columns)
          .eq('showroom_id', showroomId)
          .order('is_default', ascending: false)
          .order('bank_name');
      return <BankAccount>[for (final Map<String, dynamic> row in rows) BankAccount.fromJson(row)];
    });
  }

  @override
  Future<List<IndianState>> states() {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows =
          await client.from('states').select('code, name').eq('is_active', true).order('name');
      return <IndianState>[for (final Map<String, dynamic> row in rows) IndianState.fromJson(row)];
    });
  }

  @override
  Future<String> create(Showroom showroom) {
    return ErrorMapper.guard(
      () async => await client.rpc<String>('rpc_create_showroom', params: <String, Object?>{'p_showroom': showroom.toJson()}),
    );
  }

  @override
  Future<void> update(String id, Showroom showroom) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows =
          await client.from('showrooms').update(showroom.toJson()).eq('id', id).select('id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> setActive(String id, {required bool active}) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows =
          await client.from('showrooms').update(<String, Object?>{'is_active': active}).eq('id', id).select('id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> updateSettings(ShowroomSettings settings) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('showroom_settings')
          .update(settings.toJson())
          .eq('showroom_id', settings.showroomId)
          .select('showroom_id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> saveBankAccount(BankAccount account) {
    return ErrorMapper.guard(() async {
      if (account.id == null) {
        await client.from('bank_accounts').insert(account.toJson());
        return;
      }
      final List<Map<String, dynamic>> rows =
          await client.from('bank_accounts').update(account.toJson()).eq('id', account.id!).select('id');
      ErrorMapper.requireChanged(rows);
    });
  }

  @override
  Future<void> deleteBankAccount(String id) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client.from('bank_accounts').delete().eq('id', id).select('id');
      ErrorMapper.requireChanged(rows);
    });
  }
}

final Provider<ShowroomsRepository> showroomsRepositoryProvider = Provider<ShowroomsRepository>(
  (Ref ref) => SupabaseShowroomsRepository(Supabase.instance.client),
);
