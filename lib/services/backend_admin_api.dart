import '../models/backend_server_model.dart';
import '../models/backend_session_info.dart';

/// Routes admin Spring multi-tenant (STORE-ALL et backends compatibles).
class BackendAdminApi {
  BackendAdminApi._();

  static String? adminOrdersUrl({
    required BackendServer backend,
    required BackendSessionInfo session,
    required int? managerStoreId,
    int size = 200,
  }) {
    if (session.isSuperAdmin) {
      final code = backend.storeCode.trim().toLowerCase();
      final storeFilter =
          code.isNotEmpty ? '&storeCode=${Uri.encodeComponent(code)}' : '';
      return '${backend.origin}/api/delivery/global/orders?size=$size&sort=createdAt,desc$storeFilter';
    }
    final storeId = managerStoreId ?? session.storeId;
    if (storeId != null && storeId > 0) {
      return '${backend.origin}/api/manager/$storeId/orders?size=$size&sort=createdAt,desc';
    }
    return null;
  }

  static String? adminStatsUrl({
    required BackendServer backend,
    required BackendSessionInfo session,
    required int? managerStoreId,
  }) {
    if (session.isSuperAdmin) return null;
    final storeId = managerStoreId ?? session.storeId;
    if (storeId != null && storeId > 0) {
      return '${backend.origin}/api/manager/$storeId/dashboard/stats';
    }
    return null;
  }

  static String adminUsersUrl({
    required BackendServer backend,
    required int managerStoreId,
  }) =>
      '${backend.origin}/api/manager/$managerStoreId/users';

  static String adminUserUrl({
    required BackendServer backend,
    required int managerStoreId,
    required int userId,
  }) =>
      '${backend.origin}/api/manager/$managerStoreId/users/$userId';

  static String? adminOrderDetailUrl({
    required BackendServer backend,
    required int storeId,
    required int orderId,
  }) {
    if (storeId <= 0 || orderId <= 0) return null;
    return '${backend.origin}/api/manager/$storeId/orders/$orderId';
  }
}
