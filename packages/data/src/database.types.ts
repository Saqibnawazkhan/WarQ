export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.15"
  }
  public: {
    Tables: {
      activity_logs: {
        Row: {
          actor_id: string | null
          actor_name: string
          created_at: string
          id: string
          message: string
          meta: Json
          organization_id: string | null
          type: Database["public"]["Enums"]["activity_type"]
        }
        Insert: {
          actor_id?: string | null
          actor_name: string
          created_at?: string
          id?: string
          message: string
          meta?: Json
          organization_id?: string | null
          type: Database["public"]["Enums"]["activity_type"]
        }
        Update: {
          actor_id?: string | null
          actor_name?: string
          created_at?: string
          id?: string
          message?: string
          meta?: Json
          organization_id?: string | null
          type?: Database["public"]["Enums"]["activity_type"]
        }
        Relationships: [
          {
            foreignKeyName: "activity_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
          {
            foreignKeyName: "activity_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "activity_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
        ]
      }
      assessments: {
        Row: {
          class_id: string
          created_at: string
          date: string
          id: string
          name: string
          total_marks: number
          type: Database["public"]["Enums"]["assessment_type"]
          updated_at: string
        }
        Insert: {
          class_id: string
          created_at?: string
          date: string
          id?: string
          name: string
          total_marks: number
          type: Database["public"]["Enums"]["assessment_type"]
          updated_at?: string
        }
        Update: {
          class_id?: string
          created_at?: string
          date?: string
          id?: string
          name?: string
          total_marks?: number
          type?: Database["public"]["Enums"]["assessment_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "assessments_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "v_class_attendance"
            referencedColumns: ["class_id"]
          },
        ]
      }
      attendance_records: {
        Row: {
          mark: Database["public"]["Enums"]["attendance_mark"]
          session_id: string
          student_id: string
        }
        Insert: {
          mark?: Database["public"]["Enums"]["attendance_mark"]
          session_id: string
          student_id: string
        }
        Update: {
          mark?: Database["public"]["Enums"]["attendance_mark"]
          session_id?: string
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_records_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "attendance_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_records_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_records_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "v_student_performance"
            referencedColumns: ["student_id"]
          },
        ]
      }
      attendance_sessions: {
        Row: {
          class_id: string
          created_at: string
          date: string
          id: string
          taken_by: string | null
          updated_at: string
        }
        Insert: {
          class_id: string
          created_at?: string
          date: string
          id?: string
          taken_by?: string | null
          updated_at?: string
        }
        Update: {
          class_id?: string
          created_at?: string
          date?: string
          id?: string
          taken_by?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_sessions_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_sessions_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "v_class_attendance"
            referencedColumns: ["class_id"]
          },
          {
            foreignKeyName: "attendance_sessions_taken_by_fkey"
            columns: ["taken_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_sessions_taken_by_fkey"
            columns: ["taken_by"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_sessions_taken_by_fkey"
            columns: ["taken_by"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_sessions_taken_by_fkey"
            columns: ["taken_by"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      classes: {
        Row: {
          archived_at: string | null
          color_index: number
          created_at: string
          id: string
          name: string
          organization_id: string | null
          section: string
          session: string
          teacher_id: string
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          color_index?: number
          created_at?: string
          id?: string
          name: string
          organization_id?: string | null
          section: string
          session: string
          teacher_id: string
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          color_index?: number
          created_at?: string
          id?: string
          name?: string
          organization_id?: string | null
          section?: string
          session?: string
          teacher_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      grade_scales: {
        Row: {
          bands: Json
          created_at: string
          id: string
          organization_id: string | null
          updated_at: string
        }
        Insert: {
          bands: Json
          created_at?: string
          id?: string
          organization_id?: string | null
          updated_at?: string
        }
        Update: {
          bands?: Json
          created_at?: string
          id?: string
          organization_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "grade_scales_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grade_scales_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "grade_scales_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grade_scales_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
        ]
      }
      invitations: {
        Row: {
          accepted_at: string | null
          accepted_by: string | null
          created_at: string
          email: string
          expires_at: string
          full_name: string
          id: string
          invited_by: string | null
          organization_id: string
          sent_via: Database["public"]["Enums"]["notification_channel"]
          status: Database["public"]["Enums"]["invitation_status"]
          token: string
        }
        Insert: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          email: string
          expires_at?: string
          full_name: string
          id?: string
          invited_by?: string | null
          organization_id: string
          sent_via?: Database["public"]["Enums"]["notification_channel"]
          status?: Database["public"]["Enums"]["invitation_status"]
          token?: string
        }
        Update: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          email?: string
          expires_at?: string
          full_name?: string
          id?: string
          invited_by?: string | null
          organization_id?: string
          sent_via?: Database["public"]["Enums"]["notification_channel"]
          status?: Database["public"]["Enums"]["invitation_status"]
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "invitations_accepted_by_fkey"
            columns: ["accepted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_accepted_by_fkey"
            columns: ["accepted_by"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_accepted_by_fkey"
            columns: ["accepted_by"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_accepted_by_fkey"
            columns: ["accepted_by"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
          {
            foreignKeyName: "invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
          {
            foreignKeyName: "invitations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "invitations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
        ]
      }
      marks: {
        Row: {
          assessment_id: string
          score: number | null
          student_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          assessment_id: string
          score?: number | null
          student_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          assessment_id?: string
          score?: number | null
          student_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "marks_assessment_id_fkey"
            columns: ["assessment_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "marks_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "marks_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "v_student_performance"
            referencedColumns: ["student_id"]
          },
          {
            foreignKeyName: "marks_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "marks_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "marks_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "marks_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          id: string
          meta: Json
          profile_id: string
          read_at: string | null
          title: string
          type: Database["public"]["Enums"]["activity_type"]
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          meta?: Json
          profile_id: string
          read_at?: string | null
          title: string
          type?: Database["public"]["Enums"]["activity_type"]
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          meta?: Json
          profile_id?: string
          read_at?: string | null
          title?: string
          type?: Database["public"]["Enums"]["activity_type"]
        }
        Relationships: [
          {
            foreignKeyName: "notifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      organizations: {
        Row: {
          approved_at: string | null
          city: string
          created_at: string
          email: string
          id: string
          name: string
          owner_profile_id: string | null
          phone: string | null
          requested_at: string
          status: Database["public"]["Enums"]["account_status"]
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          city: string
          created_at?: string
          email: string
          id?: string
          name: string
          owner_profile_id?: string | null
          phone?: string | null
          requested_at?: string
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          city?: string
          created_at?: string
          email?: string
          id?: string
          name?: string
          owner_profile_id?: string | null
          phone?: string | null
          requested_at?: string
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organizations_owner_fkey"
            columns: ["owner_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organizations_owner_fkey"
            columns: ["owner_profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organizations_owner_fkey"
            columns: ["owner_profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organizations_owner_fkey"
            columns: ["owner_profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          email: string
          full_name: string
          id: string
          organization_id: string | null
          phone: string | null
          role: Database["public"]["Enums"]["user_role"]
          status: Database["public"]["Enums"]["account_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          email: string
          full_name: string
          id: string
          organization_id?: string | null
          phone?: string | null
          role: Database["public"]["Enums"]["user_role"]
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string
          full_name?: string
          id?: string
          organization_id?: string | null
          phone?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
        ]
      }
      reminder_logs: {
        Row: {
          channel: Database["public"]["Enums"]["notification_channel"]
          days_before: number
          id: string
          message: string
          sent_at: string
          subscription_id: string
        }
        Insert: {
          channel: Database["public"]["Enums"]["notification_channel"]
          days_before: number
          id?: string
          message: string
          sent_at?: string
          subscription_id: string
        }
        Update: {
          channel?: Database["public"]["Enums"]["notification_channel"]
          days_before?: number
          id?: string
          message?: string
          sent_at?: string
          subscription_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reminder_logs_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminder_logs_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["subscription_id"]
          },
          {
            foreignKeyName: "reminder_logs_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["subscription_id"]
          },
          {
            foreignKeyName: "reminder_logs_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_admin_subscriptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminder_logs_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_effective_subscriptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminder_logs_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_pending_requests"
            referencedColumns: ["subscription_id"]
          },
        ]
      }
      reminder_settings: {
        Row: {
          days: number[]
          id: boolean
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          days?: number[]
          id?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          days?: number[]
          id?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reminder_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminder_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminder_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminder_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string
          generated_by: string | null
          id: string
          kind: Database["public"]["Enums"]["report_kind"]
          organization_id: string | null
          storage_path: string
          subject_id: string | null
        }
        Insert: {
          created_at?: string
          generated_by?: string | null
          id?: string
          kind: Database["public"]["Enums"]["report_kind"]
          organization_id?: string | null
          storage_path: string
          subject_id?: string | null
        }
        Update: {
          created_at?: string
          generated_by?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["report_kind"]
          organization_id?: string | null
          storage_path?: string
          subject_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reports_generated_by_fkey"
            columns: ["generated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_generated_by_fkey"
            columns: ["generated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_generated_by_fkey"
            columns: ["generated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_generated_by_fkey"
            columns: ["generated_by"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
          {
            foreignKeyName: "reports_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "reports_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
        ]
      }
      student_contacts: {
        Row: {
          created_at: string
          id: string
          label: Database["public"]["Enums"]["contact_label"]
          phone: string
          receives_alerts: boolean
          student_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          label: Database["public"]["Enums"]["contact_label"]
          phone: string
          receives_alerts?: boolean
          student_id: string
        }
        Update: {
          created_at?: string
          id?: string
          label?: Database["public"]["Enums"]["contact_label"]
          phone?: string
          receives_alerts?: boolean
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_contacts_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_contacts_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "v_student_performance"
            referencedColumns: ["student_id"]
          },
        ]
      }
      students: {
        Row: {
          class_id: string
          created_at: string
          full_name: string
          id: string
          roll_no: string
          updated_at: string
        }
        Insert: {
          class_id: string
          created_at?: string
          full_name: string
          id?: string
          roll_no: string
          updated_at?: string
        }
        Update: {
          class_id?: string
          created_at?: string
          full_name?: string
          id?: string
          roll_no?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "students_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "v_class_attendance"
            referencedColumns: ["class_id"]
          },
        ]
      }
      subscription_events: {
        Row: {
          action: Database["public"]["Enums"]["subscription_action"]
          actor_id: string | null
          created_at: string
          from_date: string | null
          id: string
          note: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          subscription_id: string
          to_date: string | null
        }
        Insert: {
          action: Database["public"]["Enums"]["subscription_action"]
          actor_id?: string | null
          created_at?: string
          from_date?: string | null
          id?: string
          note?: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          subscription_id: string
          to_date?: string | null
        }
        Update: {
          action?: Database["public"]["Enums"]["subscription_action"]
          actor_id?: string | null
          created_at?: string
          from_date?: string | null
          id?: string
          note?: string | null
          plan?: Database["public"]["Enums"]["subscription_plan"]
          subscription_id?: string
          to_date?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subscription_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscription_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscription_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscription_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
          {
            foreignKeyName: "subscription_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscription_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["subscription_id"]
          },
          {
            foreignKeyName: "subscription_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["subscription_id"]
          },
          {
            foreignKeyName: "subscription_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_admin_subscriptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscription_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_effective_subscriptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscription_events_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "v_pending_requests"
            referencedColumns: ["subscription_id"]
          },
        ]
      }
      subscriptions: {
        Row: {
          created_at: string
          currency: string
          ends_at: string | null
          id: string
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["subscription_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          currency?: string
          ends_at?: string | null
          id?: string
          organization_id?: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents?: number | null
          profile_id?: string | null
          starts_at?: string | null
          status?: Database["public"]["Enums"]["subscription_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          currency?: string
          ends_at?: string | null
          id?: string
          organization_id?: string | null
          plan?: Database["public"]["Enums"]["subscription_plan"]
          price_cents?: number | null
          profile_id?: string | null
          starts_at?: string | null
          status?: Database["public"]["Enums"]["subscription_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
    }
    Views: {
      v_admin_individual_teachers: {
        Row: {
          account_status: Database["public"]["Enums"]["account_status"] | null
          class_count: number | null
          created_at: string | null
          days_remaining: number | null
          email: string | null
          ends_at: string | null
          full_name: string | null
          grants_access: boolean | null
          id: string | null
          phone: string | null
          plan: Database["public"]["Enums"]["subscription_plan"] | null
          starts_at: string | null
          status:
            | Database["public"]["Enums"]["effective_subscription_status"]
            | null
          student_count: number | null
          subscription_id: string | null
        }
        Relationships: []
      }
      v_admin_org_admins: {
        Row: {
          account_status: Database["public"]["Enums"]["account_status"] | null
          city: string | null
          created_at: string | null
          email: string | null
          ends_at: string | null
          full_name: string | null
          id: string | null
          is_owner: boolean | null
          organization_id: string | null
          organization_name: string | null
          phone: string | null
          plan: Database["public"]["Enums"]["subscription_plan"] | null
          subscription_status:
            | Database["public"]["Enums"]["effective_subscription_status"]
            | null
        }
        Relationships: []
      }
      v_admin_organizations: {
        Row: {
          account_status: Database["public"]["Enums"]["account_status"] | null
          admin_email: string | null
          admin_name: string | null
          admin_profile_id: string | null
          approved_at: string | null
          city: string | null
          class_count: number | null
          created_at: string | null
          days_remaining: number | null
          email: string | null
          ends_at: string | null
          grants_access: boolean | null
          id: string | null
          name: string | null
          phone: string | null
          plan: Database["public"]["Enums"]["subscription_plan"] | null
          requested_at: string | null
          starts_at: string | null
          status:
            | Database["public"]["Enums"]["effective_subscription_status"]
            | null
          stored_status:
            | Database["public"]["Enums"]["subscription_status"]
            | null
          student_count: number | null
          subscription_id: string | null
          teacher_count: number | null
        }
        Relationships: []
      }
      v_admin_subscriptions: {
        Row: {
          city: string | null
          created_at: string | null
          currency: string | null
          days_remaining: number | null
          ends_at: string | null
          grants_access: boolean | null
          id: string | null
          kind: string | null
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"] | null
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status:
            | Database["public"]["Enums"]["effective_subscription_status"]
            | null
          stored_status:
            | Database["public"]["Enums"]["subscription_status"]
            | null
          subject_email: string | null
          subject_name: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      v_class_attendance: {
        Row: {
          absent_total: number | null
          assessment_count: number | null
          attendance_percent: number | null
          class_id: string | null
          color_index: number | null
          last_session_date: string | null
          late_total: number | null
          name: string | null
          organization_id: string | null
          present_total: number | null
          section: string | null
          session: string | null
          session_count: number | null
          student_count: number | null
          teacher_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      v_effective_subscriptions: {
        Row: {
          created_at: string | null
          currency: string | null
          days_remaining: number | null
          ends_at: string | null
          grants_access: boolean | null
          id: string | null
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"] | null
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status:
            | Database["public"]["Enums"]["effective_subscription_status"]
            | null
          stored_status:
            | Database["public"]["Enums"]["subscription_status"]
            | null
        }
        Insert: {
          created_at?: string | null
          currency?: string | null
          days_remaining?: never
          ends_at?: string | null
          grants_access?: never
          id?: string | null
          organization_id?: string | null
          plan?: Database["public"]["Enums"]["subscription_plan"] | null
          price_cents?: number | null
          profile_id?: string | null
          starts_at?: string | null
          status?: never
          stored_status?:
            | Database["public"]["Enums"]["subscription_status"]
            | null
        }
        Update: {
          created_at?: string | null
          currency?: string | null
          days_remaining?: never
          ends_at?: string | null
          grants_access?: never
          id?: string | null
          organization_id?: string | null
          plan?: Database["public"]["Enums"]["subscription_plan"] | null
          price_cents?: number | null
          profile_id?: string | null
          starts_at?: string | null
          status?: never
          stored_status?:
            | Database["public"]["Enums"]["subscription_status"]
            | null
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      v_org_overview: {
        Row: {
          attendance_percent: number | null
          city: string | null
          class_count: number | null
          classes_marked_today: number | null
          name: string | null
          organization_id: string | null
          status: Database["public"]["Enums"]["account_status"] | null
          student_count: number | null
          teacher_count: number | null
        }
        Insert: {
          attendance_percent?: never
          city?: string | null
          class_count?: never
          classes_marked_today?: never
          name?: string | null
          organization_id?: string | null
          status?: Database["public"]["Enums"]["account_status"] | null
          student_count?: never
          teacher_count?: never
        }
        Update: {
          attendance_percent?: never
          city?: string | null
          class_count?: never
          classes_marked_today?: never
          name?: string | null
          organization_id?: string | null
          status?: Database["public"]["Enums"]["account_status"] | null
          student_count?: never
          teacher_count?: never
        }
        Relationships: []
      }
      v_pending_requests: {
        Row: {
          city: string | null
          kind: string | null
          organization_id: string | null
          phone: string | null
          plan: Database["public"]["Enums"]["subscription_plan"] | null
          profile_id: string | null
          requested_at: string | null
          subject_email: string | null
          subject_name: string | null
          subscription_id: string | null
          teacher_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
        ]
      }
      v_platform_overview: {
        Row: {
          active_organization_count: number | null
          active_subscription_count: number | null
          expired_count: number | null
          expiring_soon_count: number | null
          individual_teacher_count: number | null
          monthly_count: number | null
          organization_count: number | null
          organization_teacher_count: number | null
          pending_count: number | null
          permanent_count: number | null
          yearly_count: number | null
        }
        Relationships: []
      }
      v_student_performance: {
        Row: {
          absent: number | null
          assessments_marked: number | null
          assessments_pending: number | null
          attendance_percent: number | null
          class_id: string | null
          full_name: string | null
          grade: string | null
          late: number | null
          marks_percent: number | null
          obtained: number | null
          organization_id: string | null
          present: number | null
          roll_no: string | null
          sessions: number | null
          student_id: string | null
          teacher_id: string | null
          total: number | null
        }
        Relationships: [
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "v_org_overview"
            referencedColumns: ["organization_id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_individual_teachers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_org_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "v_admin_organizations"
            referencedColumns: ["admin_profile_id"]
          },
          {
            foreignKeyName: "students_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "v_class_attendance"
            referencedColumns: ["class_id"]
          },
        ]
      }
    }
    Functions: {
      accept_invitation: { Args: { invitation_token: string }; Returns: string }
      approve_subscription: {
        Args: { target_subscription: string }
        Returns: {
          created_at: string
          currency: string
          ends_at: string | null
          id: string
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["subscription_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "subscriptions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      auth_org_id: { Args: never; Returns: string }
      auth_role: {
        Args: never
        Returns: Database["public"]["Enums"]["user_role"]
      }
      bootstrap_main_admin: { Args: { admin_email: string }; Returns: string }
      can_read_class: { Args: { target_class: string }; Returns: boolean }
      fn_effective_subscription_status: {
        Args: {
          as_of?: string
          ends_at: string
          plan: Database["public"]["Enums"]["subscription_plan"]
          status: Database["public"]["Enums"]["subscription_status"]
        }
        Returns: Database["public"]["Enums"]["effective_subscription_status"]
      }
      fn_expiring_soon_days: { Args: never; Returns: number }
      fn_grade_for: {
        Args: { percent: number; target_org?: string }
        Returns: string
      }
      fn_grade_scale_is_valid: { Args: { bands: Json }; Returns: boolean }
      fn_has_access: { Args: { target_profile: string }; Returns: boolean }
      fn_percentage: {
        Args: { obtained: number; total: number }
        Returns: number
      }
      fn_period_end: {
        Args: {
          plan: Database["public"]["Enums"]["subscription_plan"]
          starts: string
        }
        Returns: string
      }
      fn_reminder_days_valid: { Args: { days: number[] }; Returns: boolean }
      fn_require_main_admin: { Args: never; Returns: undefined }
      has_access: { Args: never; Returns: boolean }
      is_main_admin: { Args: never; Returns: boolean }
      is_org_admin_of: { Args: { target_org: string }; Returns: boolean }
      me: { Args: never; Returns: Json }
      owns_class: { Args: { target_class: string }; Returns: boolean }
      reactivate_subscription: {
        Args: { target_subscription: string }
        Returns: {
          created_at: string
          currency: string
          ends_at: string | null
          id: string
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["subscription_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "subscriptions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      reject_subscription: {
        Args: { reason?: string; target_subscription: string }
        Returns: {
          created_at: string
          currency: string
          ends_at: string | null
          id: string
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["subscription_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "subscriptions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      renew_subscription: {
        Args: { target_subscription: string }
        Returns: {
          created_at: string
          currency: string
          ends_at: string | null
          id: string
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["subscription_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "subscriptions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      suspend_subscription: {
        Args: { reason?: string; target_subscription: string }
        Returns: {
          created_at: string
          currency: string
          ends_at: string | null
          id: string
          organization_id: string | null
          plan: Database["public"]["Enums"]["subscription_plan"]
          price_cents: number | null
          profile_id: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["subscription_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "subscriptions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      account_status: "pending" | "active" | "suspended"
      activity_type:
        | "attendance"
        | "marks"
        | "alerts"
        | "admin"
        | "subscription"
      assessment_type:
        | "quiz"
        | "assignment"
        | "midterm"
        | "final"
        | "project"
        | "lab"
      attendance_mark: "present" | "absent" | "late"
      contact_label: "father" | "mother" | "guardian" | "student"
      effective_subscription_status:
        | "pending"
        | "active"
        | "expiring_soon"
        | "expired"
        | "suspended"
      invitation_status: "sent" | "accepted" | "expired" | "revoked"
      notification_channel: "email" | "whatsapp" | "in_app"
      report_kind: "student" | "class" | "organization" | "platform"
      subscription_action:
        | "requested"
        | "approved"
        | "rejected"
        | "renewed"
        | "extended"
        | "suspended"
        | "reactivated"
        | "expired"
      subscription_plan: "monthly" | "yearly" | "permanent"
      subscription_status: "pending" | "active" | "suspended"
      user_role: "main_admin" | "org_admin" | "teacher"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      account_status: ["pending", "active", "suspended"],
      activity_type: ["attendance", "marks", "alerts", "admin", "subscription"],
      assessment_type: [
        "quiz",
        "assignment",
        "midterm",
        "final",
        "project",
        "lab",
      ],
      attendance_mark: ["present", "absent", "late"],
      contact_label: ["father", "mother", "guardian", "student"],
      effective_subscription_status: [
        "pending",
        "active",
        "expiring_soon",
        "expired",
        "suspended",
      ],
      invitation_status: ["sent", "accepted", "expired", "revoked"],
      notification_channel: ["email", "whatsapp", "in_app"],
      report_kind: ["student", "class", "organization", "platform"],
      subscription_action: [
        "requested",
        "approved",
        "rejected",
        "renewed",
        "extended",
        "suspended",
        "reactivated",
        "expired",
      ],
      subscription_plan: ["monthly", "yearly", "permanent"],
      subscription_status: ["pending", "active", "suspended"],
      user_role: ["main_admin", "org_admin", "teacher"],
    },
  },
} as const
