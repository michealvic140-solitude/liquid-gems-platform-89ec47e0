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
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      advertisements: {
        Row: {
          created_at: string
          id: string
          image_url: string
          is_active: boolean
          link_url: string | null
          title: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url: string
          is_active?: boolean
          link_url?: string | null
          title: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string
          is_active?: boolean
          link_url?: string | null
          title?: string
        }
        Relationships: []
      }
      announcements: {
        Row: {
          body: string | null
          created_at: string
          id: string
          image_url: string | null
          is_active: boolean
          title: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          title: string
        }
        Update: {
          body?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          title?: string
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          about_us: string | null
          admin_ai_enabled: boolean
          admin_ai_model: string | null
          challenge_reward_multiplier: number
          contact_email: string | null
          contact_phone: string | null
          contact_whatsapp: string | null
          daily_login_base_reward: number
          daily_login_bonus_per_day: number
          daily_login_enabled: boolean
          daily_login_max_streak: number
          emblem_auto_approve: boolean
          exposure_warn_pct: number
          friends_enabled: boolean
          gift_daily_limit: number
          gift_enabled: boolean
          gift_fee_pct: number
          gift_max_per_tx: number
          gift_min_amount: number
          hero_tagline: string | null
          house_low_balance: number
          id: number
          maintenance_message: string | null
          maintenance_mode: boolean
          max_payout: number
          max_selections_per_ticket: number
          min_selections_per_ticket: number
          min_stake: number
          min_withdrawal: number
          popup_ad_active: boolean
          popup_ad_image: string | null
          popup_ad_link: string | null
          popup_ad_size: string | null
          popup_ad_text: string | null
          push_endpoint_url: string | null
          referral_bonus_referee: number
          referral_bonus_referrer: number
          spin_cooldown_hours: number
          spin_enabled: boolean
          spin_max_reward: number
          spin_min_reward: number
          terms_content: string | null
          updated_at: string
          vapid_public_key: string | null
          vapid_subject: string | null
          vip_enabled: boolean
          vip_token_multipliers: Json
          virtual_animation_seconds: number
          virtual_concurrent_rounds: number
          virtual_cycle_last_tick: string | null
          virtual_cycle_running: boolean
          virtual_max_payout: number
          virtual_max_score: number
          virtual_max_selections: number
          virtual_max_stake: number
          virtual_min_selections: number
          virtual_min_stake: number
          virtual_payout_multiplier: number
          virtual_round_duration_seconds: number
          virtual_win_bonus_tokens: number
          virtual_xp_per_win: number
          why_trust_us: string | null
          xp_per_bet: number
          xp_per_login: number
          xp_per_referral: number
          xp_per_win: number
        }
        Insert: {
          about_us?: string | null
          admin_ai_enabled?: boolean
          admin_ai_model?: string | null
          challenge_reward_multiplier?: number
          contact_email?: string | null
          contact_phone?: string | null
          contact_whatsapp?: string | null
          daily_login_base_reward?: number
          daily_login_bonus_per_day?: number
          daily_login_enabled?: boolean
          daily_login_max_streak?: number
          emblem_auto_approve?: boolean
          exposure_warn_pct?: number
          friends_enabled?: boolean
          gift_daily_limit?: number
          gift_enabled?: boolean
          gift_fee_pct?: number
          gift_max_per_tx?: number
          gift_min_amount?: number
          hero_tagline?: string | null
          house_low_balance?: number
          id?: number
          maintenance_message?: string | null
          maintenance_mode?: boolean
          max_payout?: number
          max_selections_per_ticket?: number
          min_selections_per_ticket?: number
          min_stake?: number
          min_withdrawal?: number
          popup_ad_active?: boolean
          popup_ad_image?: string | null
          popup_ad_link?: string | null
          popup_ad_size?: string | null
          popup_ad_text?: string | null
          push_endpoint_url?: string | null
          referral_bonus_referee?: number
          referral_bonus_referrer?: number
          spin_cooldown_hours?: number
          spin_enabled?: boolean
          spin_max_reward?: number
          spin_min_reward?: number
          terms_content?: string | null
          updated_at?: string
          vapid_public_key?: string | null
          vapid_subject?: string | null
          vip_enabled?: boolean
          vip_token_multipliers?: Json
          virtual_animation_seconds?: number
          virtual_concurrent_rounds?: number
          virtual_cycle_last_tick?: string | null
          virtual_cycle_running?: boolean
          virtual_max_payout?: number
          virtual_max_score?: number
          virtual_max_selections?: number
          virtual_max_stake?: number
          virtual_min_selections?: number
          virtual_min_stake?: number
          virtual_payout_multiplier?: number
          virtual_round_duration_seconds?: number
          virtual_win_bonus_tokens?: number
          virtual_xp_per_win?: number
          why_trust_us?: string | null
          xp_per_bet?: number
          xp_per_login?: number
          xp_per_referral?: number
          xp_per_win?: number
        }
        Update: {
          about_us?: string | null
          admin_ai_enabled?: boolean
          admin_ai_model?: string | null
          challenge_reward_multiplier?: number
          contact_email?: string | null
          contact_phone?: string | null
          contact_whatsapp?: string | null
          daily_login_base_reward?: number
          daily_login_bonus_per_day?: number
          daily_login_enabled?: boolean
          daily_login_max_streak?: number
          emblem_auto_approve?: boolean
          exposure_warn_pct?: number
          friends_enabled?: boolean
          gift_daily_limit?: number
          gift_enabled?: boolean
          gift_fee_pct?: number
          gift_max_per_tx?: number
          gift_min_amount?: number
          hero_tagline?: string | null
          house_low_balance?: number
          id?: number
          maintenance_message?: string | null
          maintenance_mode?: boolean
          max_payout?: number
          max_selections_per_ticket?: number
          min_selections_per_ticket?: number
          min_stake?: number
          min_withdrawal?: number
          popup_ad_active?: boolean
          popup_ad_image?: string | null
          popup_ad_link?: string | null
          popup_ad_size?: string | null
          popup_ad_text?: string | null
          push_endpoint_url?: string | null
          referral_bonus_referee?: number
          referral_bonus_referrer?: number
          spin_cooldown_hours?: number
          spin_enabled?: boolean
          spin_max_reward?: number
          spin_min_reward?: number
          terms_content?: string | null
          updated_at?: string
          vapid_public_key?: string | null
          vapid_subject?: string | null
          vip_enabled?: boolean
          vip_token_multipliers?: Json
          virtual_animation_seconds?: number
          virtual_concurrent_rounds?: number
          virtual_cycle_last_tick?: string | null
          virtual_cycle_running?: boolean
          virtual_max_payout?: number
          virtual_max_score?: number
          virtual_max_selections?: number
          virtual_max_stake?: number
          virtual_min_selections?: number
          virtual_min_stake?: number
          virtual_payout_multiplier?: number
          virtual_round_duration_seconds?: number
          virtual_win_bonus_tokens?: number
          virtual_xp_per_win?: number
          why_trust_us?: string | null
          xp_per_bet?: number
          xp_per_login?: number
          xp_per_referral?: number
          xp_per_win?: number
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          id: string
          metadata: Json
          target_id: string | null
          target_type: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          id?: string
          metadata?: Json
          target_id?: string | null
          target_type?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          id?: string
          metadata?: Json
          target_id?: string | null
          target_type?: string | null
        }
        Relationships: []
      }
      ban_appeals: {
        Row: {
          admin_response: string | null
          created_at: string
          id: string
          message: string
          reviewed_at: string | null
          status: string
          user_id: string
        }
        Insert: {
          admin_response?: string | null
          created_at?: string
          id?: string
          message: string
          reviewed_at?: string | null
          status?: string
          user_id: string
        }
        Update: {
          admin_response?: string | null
          created_at?: string
          id?: string
          message?: string
          reviewed_at?: string | null
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      bet_selections: {
        Row: {
          bet_id: string
          created_at: string
          id: string
          locked_odds: number
          market_id: string | null
          match_id: string | null
          odd_id: string | null
          result: Database["public"]["Enums"]["selection_result"] | null
          selection_label: string
        }
        Insert: {
          bet_id: string
          created_at?: string
          id?: string
          locked_odds: number
          market_id?: string | null
          match_id?: string | null
          odd_id?: string | null
          result?: Database["public"]["Enums"]["selection_result"] | null
          selection_label: string
        }
        Update: {
          bet_id?: string
          created_at?: string
          id?: string
          locked_odds?: number
          market_id?: string | null
          match_id?: string | null
          odd_id?: string | null
          result?: Database["public"]["Enums"]["selection_result"] | null
          selection_label?: string
        }
        Relationships: [
          {
            foreignKeyName: "bet_selections_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: false
            referencedRelation: "bets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bet_selections_market_id_fkey"
            columns: ["market_id"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bet_selections_match_id_fkey"
            columns: ["match_id"]
            isOneToOne: false
            referencedRelation: "hot_bets_v1"
            referencedColumns: ["match_id"]
          },
          {
            foreignKeyName: "bet_selections_match_id_fkey"
            columns: ["match_id"]
            isOneToOne: false
            referencedRelation: "matches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bet_selections_odd_id_fkey"
            columns: ["odd_id"]
            isOneToOne: false
            referencedRelation: "odds"
            referencedColumns: ["id"]
          },
        ]
      }
      bets: {
        Row: {
          booking_code: string | null
          cashed_out_at: string | null
          cashout_amount: number | null
          created_at: string
          id: string
          potential_payout: number
          settled_at: string | null
          stake: number
          status: Database["public"]["Enums"]["bet_status"]
          total_odds: number
          tracking_id: string | null
          user_id: string
        }
        Insert: {
          booking_code?: string | null
          cashed_out_at?: string | null
          cashout_amount?: number | null
          created_at?: string
          id?: string
          potential_payout: number
          settled_at?: string | null
          stake: number
          status?: Database["public"]["Enums"]["bet_status"]
          total_odds: number
          tracking_id?: string | null
          user_id: string
        }
        Update: {
          booking_code?: string | null
          cashed_out_at?: string | null
          cashout_amount?: number | null
          created_at?: string
          id?: string
          potential_payout?: number
          settled_at?: string | null
          stake?: number
          status?: Database["public"]["Enums"]["bet_status"]
          total_odds?: number
          tracking_id?: string | null
          user_id?: string
        }
        Relationships: []
      }
      broadcasts: {
        Row: {
          audience: string
          body: string | null
          created_at: string
          id: string
          title: string
        }
        Insert: {
          audience?: string
          body?: string | null
          created_at?: string
          id?: string
          title: string
        }
        Update: {
          audience?: string
          body?: string | null
          created_at?: string
          id?: string
          title?: string
        }
        Relationships: []
      }
      categories: {
        Row: {
          created_at: string
          icon: string | null
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          icon?: string | null
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          icon?: string | null
          id?: string
          name?: string
        }
        Relationships: []
      }
      challenges: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          kind: string
          reward_tokens: number
          reward_xp: number
          target: number
          title: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          kind: string
          reward_tokens?: number
          reward_xp?: number
          target?: number
          title: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          kind?: string
          reward_tokens?: number
          reward_xp?: number
          target?: number
          title?: string
        }
        Relationships: []
      }
      chat_message_reactions: {
        Row: {
          created_at: string
          emoji: string
          id: string
          message_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          emoji: string
          id?: string
          message_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          emoji?: string
          id?: string
          message_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_message_reactions_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "chat_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_messages: {
        Row: {
          content: string | null
          created_at: string
          deleted_at: string | null
          deleted_by: string | null
          edited_at: string | null
          id: string
          image_url: string | null
          reply_to_id: string | null
          room: string
          user_id: string
        }
        Insert: {
          content?: string | null
          created_at?: string
          deleted_at?: string | null
          deleted_by?: string | null
          edited_at?: string | null
          id?: string
          image_url?: string | null
          reply_to_id?: string | null
          room?: string
          user_id: string
        }
        Update: {
          content?: string | null
          created_at?: string
          deleted_at?: string | null
          deleted_by?: string | null
          edited_at?: string | null
          id?: string
          image_url?: string | null
          reply_to_id?: string | null
          room?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "chat_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          banner_url: string | null
          created_at: string
          description: string | null
          ends_at: string | null
          id: string
          is_active: boolean
          title: string
        }
        Insert: {
          banner_url?: string | null
          created_at?: string
          description?: string | null
          ends_at?: string | null
          id?: string
          is_active?: boolean
          title: string
        }
        Update: {
          banner_url?: string | null
          created_at?: string
          description?: string | null
          ends_at?: string | null
          id?: string
          is_active?: boolean
          title?: string
        }
        Relationships: []
      }
      gang_emblems: {
        Row: {
          created_at: string
          id: string
          image_url: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      highlights: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          media_type: string
          media_url: string
          title: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          media_type?: string
          media_url: string
          title: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          media_type?: string
          media_url?: string
          title?: string
        }
        Relationships: []
      }
      house_transactions: {
        Row: {
          actor_id: string | null
          amount: number
          balance_after: number
          bet_id: string | null
          created_at: string
          id: string
          kind: string
          reason: string | null
          user_id: string | null
        }
        Insert: {
          actor_id?: string | null
          amount: number
          balance_after: number
          bet_id?: string | null
          created_at?: string
          id?: string
          kind: string
          reason?: string | null
          user_id?: string | null
        }
        Update: {
          actor_id?: string | null
          amount?: number
          balance_after?: number
          bet_id?: string | null
          created_at?: string
          id?: string
          kind?: string
          reason?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "house_transactions_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: false
            referencedRelation: "bets"
            referencedColumns: ["id"]
          },
        ]
      }
      house_wallet: {
        Row: {
          balance: number
          id: number
          pause_reason: string | null
          payouts_paused: boolean
          total_in: number
          total_out: number
          updated_at: string
        }
        Insert: {
          balance?: number
          id?: number
          pause_reason?: string | null
          payouts_paused?: boolean
          total_in?: number
          total_out?: number
          updated_at?: string
        }
        Update: {
          balance?: number
          id?: number
          pause_reason?: string | null
          payouts_paused?: boolean
          total_in?: number
          total_out?: number
          updated_at?: string
        }
        Relationships: []
      }
      leaderboard_overrides: {
        Row: {
          bonus_points: number
          created_at: string
          id: string
          kind: string
          manual_rank: number | null
          note: string | null
          user_id: string
        }
        Insert: {
          bonus_points?: number
          created_at?: string
          id?: string
          kind: string
          manual_rank?: number | null
          note?: string | null
          user_id: string
        }
        Update: {
          bonus_points?: number
          created_at?: string
          id?: string
          kind?: string
          manual_rank?: number | null
          note?: string | null
          user_id?: string
        }
        Relationships: []
      }
      markets: {
        Row: {
          created_at: string
          id: string
          is_open: boolean
          match_id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_open?: boolean
          match_id: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          is_open?: boolean
          match_id?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "markets_match_id_fkey"
            columns: ["match_id"]
            isOneToOne: false
            referencedRelation: "hot_bets_v1"
            referencedColumns: ["match_id"]
          },
          {
            foreignKeyName: "markets_match_id_fkey"
            columns: ["match_id"]
            isOneToOne: false
            referencedRelation: "matches"
            referencedColumns: ["id"]
          },
        ]
      }
      matches: {
        Row: {
          away_score: number
          away_team_id: string | null
          category_id: string | null
          created_at: string
          created_by: string | null
          home_score: number
          home_team_id: string | null
          id: string
          is_archived: boolean
          is_featured: boolean
          is_virtual: boolean
          location: string | null
          lock_time: string | null
          locked_at: string | null
          locked_by: string | null
          name: string | null
          settled_at: string | null
          settled_by: string | null
          start_time: string | null
          status: Database["public"]["Enums"]["match_status"]
          updated_at: string
          virtual_first_blood_team_id: string | null
          virtual_round_batch_id: string | null
          winner_team_id: string | null
        }
        Insert: {
          away_score?: number
          away_team_id?: string | null
          category_id?: string | null
          created_at?: string
          created_by?: string | null
          home_score?: number
          home_team_id?: string | null
          id?: string
          is_archived?: boolean
          is_featured?: boolean
          is_virtual?: boolean
          location?: string | null
          lock_time?: string | null
          locked_at?: string | null
          locked_by?: string | null
          name?: string | null
          settled_at?: string | null
          settled_by?: string | null
          start_time?: string | null
          status?: Database["public"]["Enums"]["match_status"]
          updated_at?: string
          virtual_first_blood_team_id?: string | null
          virtual_round_batch_id?: string | null
          winner_team_id?: string | null
        }
        Update: {
          away_score?: number
          away_team_id?: string | null
          category_id?: string | null
          created_at?: string
          created_by?: string | null
          home_score?: number
          home_team_id?: string | null
          id?: string
          is_archived?: boolean
          is_featured?: boolean
          is_virtual?: boolean
          location?: string | null
          lock_time?: string | null
          locked_at?: string | null
          locked_by?: string | null
          name?: string | null
          settled_at?: string | null
          settled_by?: string | null
          start_time?: string | null
          status?: Database["public"]["Enums"]["match_status"]
          updated_at?: string
          virtual_first_blood_team_id?: string | null
          virtual_round_batch_id?: string | null
          winner_team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "matches_away_team_id_fkey"
            columns: ["away_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_home_team_id_fkey"
            columns: ["home_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_virtual_first_blood_team_id_fkey"
            columns: ["virtual_first_blood_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_winner_team_id_fkey"
            columns: ["winner_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_prefs: {
        Row: {
          bets: boolean
          chat: boolean
          promos: boolean
          results: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          bets?: boolean
          chat?: boolean
          promos?: boolean
          results?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          bets?: boolean
          chat?: boolean
          promos?: boolean
          results?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          body: string | null
          created_at: string
          id: string
          is_read: boolean
          link: string | null
          title: string
          user_id: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          link?: string | null
          title: string
          user_id: string
        }
        Update: {
          body?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          link?: string | null
          title?: string
          user_id?: string
        }
        Relationships: []
      }
      odds: {
        Row: {
          id: string
          is_winner: boolean | null
          label: string
          market_id: string
          updated_at: string
          value: number
        }
        Insert: {
          id?: string
          is_winner?: boolean | null
          label: string
          market_id: string
          updated_at?: string
          value: number
        }
        Update: {
          id?: string
          is_winner?: boolean | null
          label?: string
          market_id?: string
          updated_at?: string
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "odds_market_id_fkey"
            columns: ["market_id"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["id"]
          },
        ]
      }
      players: {
        Row: {
          avatar_url: string | null
          created_at: string
          id: string
          is_substitute: boolean
          name: string
          position: string | null
          team_id: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          id?: string
          is_substitute?: boolean
          name: string
          position?: string | null
          team_id?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          id?: string
          is_substitute?: boolean
          name?: string
          position?: string | null
          team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "players_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          accepted_terms: boolean
          avatar_url: string | null
          ban_reason: string | null
          chat_color: string | null
          country: string | null
          created_at: string
          discord_full_name: string | null
          discord_username: string | null
          email: string | null
          emblem_status: string | null
          full_name: string
          gang_emblem_url: string | null
          gang_name: string | null
          gang_type: Database["public"]["Enums"]["gang_type"] | null
          id: string
          ingame_name: string | null
          is_banned: boolean
          is_muted: boolean
          is_restricted: boolean
          last_kicked_at: string | null
          last_login_date: string | null
          longest_streak: number
          mute_reason: string | null
          phone: string | null
          profile_banner_url: string | null
          profile_title: string | null
          referral_code: string | null
          referred_by: string | null
          restrict_reason: string | null
          server: string | null
          showcase_achievement_ids: Json
          streak_days: number
          token_balance: number
          updated_at: string
          vip_tier: string
          xp: number
        }
        Insert: {
          accepted_terms?: boolean
          avatar_url?: string | null
          ban_reason?: string | null
          chat_color?: string | null
          country?: string | null
          created_at?: string
          discord_full_name?: string | null
          discord_username?: string | null
          email?: string | null
          emblem_status?: string | null
          full_name?: string
          gang_emblem_url?: string | null
          gang_name?: string | null
          gang_type?: Database["public"]["Enums"]["gang_type"] | null
          id: string
          ingame_name?: string | null
          is_banned?: boolean
          is_muted?: boolean
          is_restricted?: boolean
          last_kicked_at?: string | null
          last_login_date?: string | null
          longest_streak?: number
          mute_reason?: string | null
          phone?: string | null
          profile_banner_url?: string | null
          profile_title?: string | null
          referral_code?: string | null
          referred_by?: string | null
          restrict_reason?: string | null
          server?: string | null
          showcase_achievement_ids?: Json
          streak_days?: number
          token_balance?: number
          updated_at?: string
          vip_tier?: string
          xp?: number
        }
        Update: {
          accepted_terms?: boolean
          avatar_url?: string | null
          ban_reason?: string | null
          chat_color?: string | null
          country?: string | null
          created_at?: string
          discord_full_name?: string | null
          discord_username?: string | null
          email?: string | null
          emblem_status?: string | null
          full_name?: string
          gang_emblem_url?: string | null
          gang_name?: string | null
          gang_type?: Database["public"]["Enums"]["gang_type"] | null
          id?: string
          ingame_name?: string | null
          is_banned?: boolean
          is_muted?: boolean
          is_restricted?: boolean
          last_kicked_at?: string | null
          last_login_date?: string | null
          longest_streak?: number
          mute_reason?: string | null
          phone?: string | null
          profile_banner_url?: string | null
          profile_title?: string | null
          referral_code?: string | null
          referred_by?: string | null
          restrict_reason?: string | null
          server?: string | null
          showcase_achievement_ids?: Json
          streak_days?: number
          token_balance?: number
          updated_at?: string
          vip_tier?: string
          xp?: number
        }
        Relationships: []
      }
      promo_code_requests: {
        Row: {
          amount: number
          created_at: string
          id: string
          reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          usage_limit: number
          user_id: string
        }
        Insert: {
          amount?: number
          created_at?: string
          id?: string
          reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          usage_limit?: number
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          usage_limit?: number
          user_id?: string
        }
        Relationships: []
      }
      promo_code_usage_v2: {
        Row: {
          amount: number
          id: string
          promo_id: string
          redeemed_at: string
          user_id: string
        }
        Insert: {
          amount?: number
          id?: string
          promo_id: string
          redeemed_at?: string
          user_id: string
        }
        Update: {
          amount?: number
          id?: string
          promo_id?: string
          redeemed_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promo_code_usage_v2_promo_id_fkey"
            columns: ["promo_id"]
            isOneToOne: false
            referencedRelation: "promo_codes"
            referencedColumns: ["id"]
          },
        ]
      }
      promo_codes: {
        Row: {
          amount: number
          code: string
          created_at: string
          id: string
          is_active: boolean
          usage_limit: number
          used_count: number
        }
        Insert: {
          amount?: number
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          usage_limit?: number
          used_count?: number
        }
        Update: {
          amount?: number
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          usage_limit?: number
          used_count?: number
        }
        Relationships: []
      }
      promo_redemptions: {
        Row: {
          amount: number
          created_at: string
          id: string
          promo_id: string
          user_id: string
        }
        Insert: {
          amount?: number
          created_at?: string
          id?: string
          promo_id: string
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          promo_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promo_redemptions_promo_id_fkey"
            columns: ["promo_id"]
            isOneToOne: false
            referencedRelation: "promo_codes"
            referencedColumns: ["id"]
          },
        ]
      }
      referrals: {
        Row: {
          created_at: string
          id: string
          referee_bonus: number
          referee_id: string
          referrer_bonus: number
          referrer_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          referee_bonus?: number
          referee_id: string
          referrer_bonus?: number
          referrer_id: string
        }
        Update: {
          created_at?: string
          id?: string
          referee_bonus?: number
          referee_id?: string
          referrer_bonus?: number
          referrer_id?: string
        }
        Relationships: []
      }
      season_points: {
        Row: {
          id: string
          points: number
          season_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          id?: string
          points?: number
          season_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          id?: string
          points?: number
          season_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "season_points_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      seasons: {
        Row: {
          created_at: string
          description: string | null
          ends_at: string | null
          id: string
          is_active: boolean
          name: string
          starts_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          ends_at?: string | null
          id?: string
          is_active?: boolean
          name: string
          starts_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          ends_at?: string | null
          id?: string
          is_active?: boolean
          name?: string
          starts_at?: string
        }
        Relationships: []
      }
      spotlights: {
        Row: {
          body: string | null
          created_at: string
          created_by: string | null
          expires_at: string | null
          headline: string | null
          id: string
          image_url: string | null
          is_active: boolean
          link_url: string | null
          message: string | null
          title: string
          user_id: string | null
        }
        Insert: {
          body?: string | null
          created_at?: string
          created_by?: string | null
          expires_at?: string | null
          headline?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          link_url?: string | null
          message?: string | null
          title?: string
          user_id?: string | null
        }
        Update: {
          body?: string | null
          created_at?: string
          created_by?: string | null
          expires_at?: string | null
          headline?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          link_url?: string | null
          message?: string | null
          title?: string
          user_id?: string | null
        }
        Relationships: []
      }
      support_tickets: {
        Row: {
          category: string | null
          created_at: string
          id: string
          status: string
          subject: string
          updated_at: string
          user_id: string
        }
        Insert: {
          category?: string | null
          created_at?: string
          id?: string
          status?: string
          subject: string
          updated_at?: string
          user_id: string
        }
        Update: {
          category?: string | null
          created_at?: string
          id?: string
          status?: string
          subject?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      teams: {
        Row: {
          created_at: string
          gang_type: Database["public"]["Enums"]["gang_type"] | null
          id: string
          logo_url: string | null
          name: string
        }
        Insert: {
          created_at?: string
          gang_type?: Database["public"]["Enums"]["gang_type"] | null
          id?: string
          logo_url?: string | null
          name: string
        }
        Update: {
          created_at?: string
          gang_type?: Database["public"]["Enums"]["gang_type"] | null
          id?: string
          logo_url?: string | null
          name?: string
        }
        Relationships: []
      }
      ticket_messages: {
        Row: {
          content: string | null
          created_at: string
          id: string
          image_url: string | null
          ticket_id: string
          user_id: string
        }
        Insert: {
          content?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          ticket_id: string
          user_id: string
        }
        Update: {
          content?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          ticket_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ticket_messages_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      token_requests: {
        Row: {
          amount: number
          created_at: string
          id: string
          note: string | null
          proof_image_url: string | null
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["request_status"]
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          note?: string | null
          proof_image_url?: string | null
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          note?: string | null
          proof_image_url?: string | null
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          user_id?: string
        }
        Relationships: []
      }
      token_transactions: {
        Row: {
          amount: number
          balance_after: number
          created_at: string
          description: string | null
          id: string
          kind: string
          metadata: Json
          user_id: string
        }
        Insert: {
          amount: number
          balance_after: number
          created_at?: string
          description?: string | null
          id?: string
          kind: string
          metadata?: Json
          user_id: string
        }
        Update: {
          amount?: number
          balance_after?: number
          created_at?: string
          description?: string | null
          id?: string
          kind?: string
          metadata?: Json
          user_id?: string
        }
        Relationships: []
      }
      user_achievements: {
        Row: {
          awarded_at: string
          code: string
          description: string | null
          icon: string | null
          id: string
          title: string
          user_id: string
        }
        Insert: {
          awarded_at?: string
          code: string
          description?: string | null
          icon?: string | null
          id?: string
          title: string
          user_id: string
        }
        Update: {
          awarded_at?: string
          code?: string
          description?: string | null
          icon?: string | null
          id?: string
          title?: string
          user_id?: string
        }
        Relationships: []
      }
      user_challenge_progress: {
        Row: {
          challenge_id: string
          claimed_at: string | null
          id: string
          progress: number
          updated_at: string
          user_id: string
        }
        Insert: {
          challenge_id: string
          claimed_at?: string | null
          id?: string
          progress?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          challenge_id?: string
          claimed_at?: string | null
          id?: string
          progress?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          assigned_by: string | null
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          assigned_by?: string | null
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          assigned_by?: string | null
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_sessions: {
        Row: {
          last_seen: string
          route: string | null
          user_agent: string | null
          user_id: string
        }
        Insert: {
          last_seen?: string
          route?: string | null
          user_agent?: string | null
          user_id: string
        }
        Update: {
          last_seen?: string
          route?: string | null
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      user_tasks: {
        Row: {
          completed_at: string | null
          created_at: string
          description: string | null
          id: string
          reward_tokens: number
          status: string
          title: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          description?: string | null
          id?: string
          reward_tokens?: number
          status?: string
          title: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          description?: string | null
          id?: string
          reward_tokens?: number
          status?: string
          title?: string
          user_id?: string
        }
        Relationships: []
      }
      virtual_house_transactions: {
        Row: {
          amount: number
          balance_after: number
          bet_id: string | null
          created_at: string
          id: string
          kind: string
          reason: string | null
          user_id: string | null
        }
        Insert: {
          amount: number
          balance_after?: number
          bet_id?: string | null
          created_at?: string
          id?: string
          kind: string
          reason?: string | null
          user_id?: string | null
        }
        Update: {
          amount?: number
          balance_after?: number
          bet_id?: string | null
          created_at?: string
          id?: string
          kind?: string
          reason?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      virtual_house_wallet: {
        Row: {
          balance: number
          id: number
          total_in: number
          total_out: number
          updated_at: string
        }
        Insert: {
          balance?: number
          id?: number
          total_in?: number
          total_out?: number
          updated_at?: string
        }
        Update: {
          balance?: number
          id?: number
          total_in?: number
          total_out?: number
          updated_at?: string
        }
        Relationships: []
      }
      virtual_payout_requests: {
        Row: {
          amount: number
          bet_id: string | null
          created_at: string
          id: string
          match_id: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          stake: number
          status: string
          user_id: string
        }
        Insert: {
          amount?: number
          bet_id?: string | null
          created_at?: string
          id?: string
          match_id?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          stake?: number
          status?: string
          user_id: string
        }
        Update: {
          amount?: number
          bet_id?: string | null
          created_at?: string
          id?: string
          match_id?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          stake?: number
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      watchlist: {
        Row: {
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          user_id: string
        }
        Update: {
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          user_id?: string
        }
        Relationships: []
      }
      withdrawal_requests: {
        Row: {
          admin_note: string | null
          amount: number
          created_at: string
          gang_name: string
          id: string
          ingame_name: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["request_status"]
          ticket_ref: string | null
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          amount: number
          created_at?: string
          gang_name: string
          id?: string
          ingame_name: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          ticket_ref?: string | null
          user_id: string
        }
        Update: {
          admin_note?: string | null
          amount?: number
          created_at?: string
          gang_name?: string
          id?: string
          ingame_name?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          ticket_ref?: string | null
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      hot_bets_v1: {
        Row: {
          avg_odds: number | null
          bets_count: number | null
          last_picked_at: string | null
          market_name: string | null
          match_id: string | null
          match_name: string | null
          match_start: string | null
          odds: number | null
          picks: number | null
          selection_label: string | null
          stake_volume: number | null
          total_stake: number | null
          users_count: number | null
        }
        Relationships: []
      }
    }
    Functions: {
      admin_adjust_xp: {
        Args: { _delta: number; _reason?: string; user_id: string }
        Returns: Json
      }
      admin_broadcast: {
        Args: {
          _body?: string
          _link?: string
          _segment?: string
          title: string
        }
        Returns: Json
      }
      admin_delete_bet: { Args: { bet_id: string }; Returns: Json }
      admin_exposure_per_match: {
        Args: never
        Returns: {
          exposure: number
          match_id: string
          match_name: string
          picks: number
        }[]
      }
      admin_lock_virtual_round: { Args: { match_id: string }; Returns: Json }
      admin_pnl_summary: { Args: { days?: number }; Returns: Json }
      admin_refund_bet: { Args: { bet_id: string }; Returns: Json }
      admin_review_virtual_payout: {
        Args: { _approve: boolean; _reason?: string; id: string }
        Returns: Json
      }
      admin_risk_summary: { Args: never; Returns: Json }
      admin_set_virtual_cycle: { Args: { _running: boolean }; Returns: Json }
      admin_suspend_bet: { Args: { bet_id: string }; Returns: Json }
      admin_unsuspend_bet: { Args: { bet_id: string }; Returns: Json }
      admin_void_bet: { Args: { bet_id: string }; Returns: Json }
      apply_referral_code: { Args: { code: string }; Returns: Json }
      approve_promo_request: {
        Args: { _note?: string; id: string }
        Returns: Json
      }
      claim_challenge: { Args: { progress_id: string }; Returns: Json }
      claim_daily_login: { Args: never; Returns: Json }
      claim_task: { Args: { task_id: string }; Returns: Json }
      create_withdrawal_request: {
        Args: {
          _gang: string
          _ingame: string
          _ticket?: string
          amount: number
        }
        Returns: Json
      }
      decline_promo_request: {
        Args: { _note?: string; id: string }
        Returns: Json
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      house_manual_adjust: {
        Args: { _reason: string; amount: number }
        Returns: Json
      }
      house_set_paused: {
        Args: { paused: boolean; reason?: string }
        Returns: Json
      }
      is_admin: { Args: { _user_id: string }; Returns: boolean }
      place_bet_ticket: {
        Args: { _selections: Json; _stake: number }
        Returns: Json
      }
      place_virtual_ticket:
        | { Args: { _selections: Json; _stake: number }; Returns: Json }
        | { Args: { payload: Json }; Returns: Json }
      redeem_promo_code: { Args: { code: string }; Returns: Json }
      resolve_virtual_round: {
        Args: {
          _away_score?: number
          _first_blood_team_id?: string
          _home_score?: number
          _match_id: string
        }
        Returns: Json
      }
      review_gang_emblem: {
        Args: { _approve: boolean; _note?: string; id: string }
        Returns: Json
      }
      review_withdrawal_request: {
        Args: { _approve: boolean; _note?: string; id: string }
        Returns: Json
      }
      server_now: { Args: never; Returns: string }
      settle_pay_winning_bet: { Args: { bet_id: string }; Returns: Json }
      user_cashout_bet: { Args: { bet_id: string }; Returns: Json }
      user_claim_virtual_payout: { Args: { bet_id: string }; Returns: Json }
      verify_xp_consistency: { Args: { user_id?: string }; Returns: Json }
      virtual_score_for_match: {
        Args: { _match_id: string }
        Returns: {
          away_score: number
          first_blood_team_id: string
          home_score: number
        }[]
      }
      virtual_seed_rand: {
        Args: { _i: number; _seed: string }
        Returns: number
      }
      virtual_tick: { Args: never; Returns: Json }
      virtual_wallet_admin_adjust: {
        Args: { delta: number; reason: string }
        Returns: Json
      }
      wipe_all_tokens: { Args: never; Returns: Json }
    }
    Enums: {
      app_role:
        | "viewer"
        | "shooter"
        | "gang_leader"
        | "registered"
        | "sponsor"
        | "moderator"
        | "admin"
      bet_status:
        | "pending"
        | "won"
        | "lost"
        | "void"
        | "cashed_out"
        | "refunded"
        | "cancelled"
        | "open"
      gang_type: "G" | "F"
      match_status: "upcoming" | "live" | "ended" | "cancelled" | "scheduled"
      request_status: "pending" | "approved" | "declined" | "denied"
      selection_result: "won" | "lost" | "void"
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
      app_role: [
        "viewer",
        "shooter",
        "gang_leader",
        "registered",
        "sponsor",
        "moderator",
        "admin",
      ],
      bet_status: [
        "pending",
        "won",
        "lost",
        "void",
        "cashed_out",
        "refunded",
        "cancelled",
        "open",
      ],
      gang_type: ["G", "F"],
      match_status: ["upcoming", "live", "ended", "cancelled", "scheduled"],
      request_status: ["pending", "approved", "declined", "denied"],
      selection_result: ["won", "lost", "void"],
    },
  },
} as const
