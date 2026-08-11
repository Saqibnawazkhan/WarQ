import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../organization_repository.dart';
import 'supabase_repository_base.dart';

/// Organizations, their teachers and invitations, backed by Supabase.
///
/// The three actions with consequences beyond a single row — inviting a
/// teacher, revoking an invitation, removing a teacher — go through database
/// functions, because each has a rule the client cannot be trusted to keep.
/// Removing a teacher in particular detaches them while leaving every class,
/// register and mark with the organization, which is what the product promises.
class SupabaseOrganizationRepository extends SupabaseRepositoryBase
    implements OrganizationRepository {
  SupabaseOrganizationRepository(super.client, super.bus);

  SupabaseQueryBuilder get _table => client.from('organizations');
  SupabaseQueryBuilder get _invitations => client.from('invitations');

  @override
  Future<Organization?> findById(String organizationId) {
    return read(() async {
      final Map<String, dynamic>? row =
          await _table.select('*').eq('id', organizationId).maybeSingle();
      return row == null ? null : Rows.organization(row);
    });
  }

  @override
  Future<Organization?> findByJoinCode(String joinCode) {
    final String code = joinCode.trim().toUpperCase();
    if (code.isEmpty) return Future<Organization?>.value();

    // The code is derived from the organization's id for display, not stored,
    // and row-level security only ever shows a person their own organization —
    // so the only organization this can match is the caller's own. There is no
    // join-by-code flow: teachers arrive through a tokenised invitation.
    return read(() async {
      final List<Map<String, dynamic>> rows = await _table.select('*').limit(1);
      if (rows.isEmpty) return null;
      final Organization organization = Rows.organization(rows.first);
      return organization.joinCode?.toUpperCase() == code ? organization : null;
    });
  }

  @override
  Future<Organization> update({
    required String organizationId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? website,
  }) {
    // Only what was passed is written. A null argument means "leave it alone",
    // which is not the same as clearing the field, and the edit form sends the
    // whole object each time anyway.
    final Map<String, dynamic> changes = <String, dynamic>{
      if (name != null) 'name': Format.clean(name),
      if (email != null) 'email': Format.cleanOrNull(email),
      if (phone != null) 'phone': Format.cleanOrNull(phone),
      if (address != null) 'address': Format.cleanOrNull(address),
      if (website != null) 'website': Format.cleanOrNull(website),
    };

    if (changes.isEmpty) {
      return read(() async {
        final Organization? current = await findById(organizationId);
        if (current == null) {
          throw const AppFailure.notFound('That organization');
        }
        return current;
      });
    }

    return write(
      () async {
        final List<Map<String, dynamic>> rows = await _table
            .update(<String, dynamic>{
              ...changes,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', organizationId)
            .select('*');

        if (rows.isEmpty) throw const AppFailure.notFound('That organization');
        return Rows.organization(rows.first);
      },
      touches: <DataEntity>{DataEntity.organizations},
      id: organizationId,
    );
  }

  @override
  Future<List<AppUser>> members(String organizationId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('profiles')
          .select('*')
          .eq('organization_id', organizationId)
          .order('full_name');
      return rows.map(Rows.user).toList(growable: false);
    });
  }

  @override
  Future<List<AppUser>> teachers(String organizationId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('profiles')
          .select('*')
          .eq('organization_id', organizationId)
          .eq('role', Rows.roleToDb(UserRole.teacher))
          .order('full_name');
      return rows.map(Rows.user).toList(growable: false);
    });
  }

  @override
  Future<Invitation> invite({
    required String organizationId,
    required String email,
    required String invitedByUserId,
    String? inviteeName,
    String? message,
  }) {
    final String address = Format.clean(email).toLowerCase();
    if (address.isEmpty) {
      throw const AppFailure.validation('An email address is required.');
    }

    // Goes through the edge function rather than straight to invite_teacher,
    // because inviting now means creating the teacher's account and emailing
    // them a password — and creating an auth user needs the service-role key,
    // which can never be in this app. The function calls invite_teacher as this
    // caller first, so every rule about who may invite whom still applies
    // before anything privileged happens.
    //
    // organizationId and invitedByUserId are not sent: both come from the
    // caller's own profile. message has nowhere to go — an invitation carries
    // no note.
    return write(
      () async {
        final FunctionResponse response = await client.functions.invoke(
          'invite-teacher',
          body: <String, dynamic>{
            'email': address,
            'full_name': Format.cleanOrNull(inviteeName) ?? address,
          },
        );

        final Map<String, dynamic> payload =
            (response.data as Map<String, dynamic>?) ?? const <String, dynamic>{};

        if (response.status >= 400) {
          throw AppFailure.validation(
            Rows.str(payload, 'error', fallback: 'The invitation could not be sent.'),
          );
        }

        // The invitation row the function created, read back so the caller gets
        // the same object the old path returned.
        final String? id = Rows.strOrNull(payload, 'invitation_id');
        if (id != null) {
          final Map<String, dynamic>? row =
              await _invitations.select('*').eq('id', id).maybeSingle();
          if (row != null) return Rows.invitation(row);
        }

        throw const AppFailure.storage(
          'The teacher was invited but the invitation could not be read back.',
        );
      },
      touches: <DataEntity>{DataEntity.invitations, DataEntity.users},
    );
  }

  @override
  Future<List<Invitation>> invitations(String organizationId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _invitations
          .select('*')
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);
      return rows.map(Rows.invitation).toList(growable: false);
    });
  }

  @override
  Future<Invitation> revokeInvitation(String invitationId) {
    return write(
      () async {
        await client.rpc<void>(
          'revoke_invitation',
          params: <String, dynamic>{'invitation_id': invitationId},
        );

        final Map<String, dynamic>? row =
            await _invitations.select('*').eq('id', invitationId).maybeSingle();
        if (row == null) throw const AppFailure.notFound('That invitation');
        return Rows.invitation(row);
      },
      touches: <DataEntity>{DataEntity.invitations},
      id: invitationId,
    );
  }

  @override
  Future<Invitation> resendInvitation(String invitationId) {
    // Nothing is actually sent: Phase 1 has no mail server, and a teacher joins
    // by registering with the invited address rather than by following a link.
    // What resending does is put the invitation back in date, which is the part
    // that had stopped working if it had expired or been revoked.
    return write(
      () async {
        final List<Map<String, dynamic>> rows = await _invitations
            .update(<String, dynamic>{
              'status': 'pending',
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 14))
                  .toIso8601String(),
            })
            .eq('id', invitationId)
            .neq('status', 'accepted')
            .select('*');

        if (rows.isEmpty) {
          // Either it does not exist, or it has already been accepted — and
          // reopening an accepted invitation would let one link admit a second
          // person.
          throw const AppFailure.validation(
            'That invitation cannot be resent. It may have already been accepted.',
          );
        }
        return Rows.invitation(rows.first);
      },
      touches: <DataEntity>{DataEntity.invitations},
      id: invitationId,
    );
  }

  @override
  Future<void> removeTeacher({
    required String organizationId,
    required String teacherId,
    required String actorUserId,
  }) {
    // The function refuses anyone outside the caller's own organization, and
    // refuses an admin removing themselves, so neither is re-checked here.
    return write(
      () => client.rpc<void>(
        'remove_teacher',
        params: <String, dynamic>{'teacher_id': teacherId},
      ),
      touches: <DataEntity>{
        DataEntity.users,
        DataEntity.organizations,
        DataEntity.activity,
      },
      id: teacherId,
    );
  }

  @override
  Future<Organization> setGradeScale({
    required String organizationId,
    required String gradeScaleId,
  }) async {
    // The link lives on grade_scales.organization_id rather than on the
    // organization, so adopting a scale means giving this organization a row
    // with those bands — and adopting the platform default means having no row
    // of its own, which is what makes it follow the default from then on.
    final Map<String, dynamic>? scale = await read(
      () => client
          .from('grade_scales')
          .select('*')
          .eq('id', gradeScaleId)
          .maybeSingle(),
    );
    if (scale == null) {
      throw const AppFailure.notFound('That grading scale');
    }

    await write(
      () async {
        if (scale['organization_id'] == null) {
          await client
              .from('grade_scales')
              .delete()
              .eq('organization_id', organizationId);
          return;
        }

        await client.from('grade_scales').upsert(
          <String, dynamic>{
            'organization_id': organizationId,
            'name': Rows.str(scale, 'name', fallback: 'Standard scale'),
            'bands': scale['bands'],
            'pass_percent': Rows.number(scale, 'pass_percent', fallback: 50),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'organization_id',
        );
      },
      touches: <DataEntity>{DataEntity.gradeScales, DataEntity.organizations},
      id: organizationId,
    );

    final Organization? organization = await findById(organizationId);
    if (organization == null) {
      throw const AppFailure.notFound('That organization');
    }
    return organization;
  }
}
