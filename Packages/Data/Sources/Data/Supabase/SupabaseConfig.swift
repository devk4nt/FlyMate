import Foundation

public enum SupabaseConfig {
    public static let url: URL = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not found in Info.plist. Check Secrets.xcconfig setup.")
        }
        return url
    }()

    public static let anonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              key != "your-anon-key" else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist. Check Secrets.xcconfig setup.")
        }
        return key
    }()

    public enum Table {
        public static let users = "users"
        public static let studies = "studies"
        public static let studyMembers = "study_members"
        public static let videos = "videos"
        public static let feedbacks = "feedbacks"
        public static let reports = "reports"
        public static let notifications = "notifications"
        public static let joinRequests = "study_join_requests"
        public static let deviceTokens = "device_tokens"
        public static let feedbackComments = "feedback_comments"
        public static let subscriptionPlans = "subscription_plans"
        public static let subscriptions = "subscriptions"
        public static let recruitPosts = "recruit_posts"
        public static let recruitComments = "recruit_comments"
        public static let blockedUsers = "blocked_users"
        public static let announcements = "announcements"
        public static let quickFeedbackWallets = "quick_feedback_wallets"
        public static let quickFeedbackRequests = "quick_feedback_requests"
        public static let quickFeedbackAssignments = "quick_feedback_assignments"
        public static let quickFeedbackReviews = "quick_feedback_reviews"
    }

    public enum Bucket {
        public static let videos = "videos"
        public static let thumbnails = "thumbnails"
        public static let profileImages = "profile-images"
    }

    public enum RealtimeChannel {
        public static let feedbacks = "feedbacks"
        public static let notifications = "notifications"
    }

    public enum RPC {
        public static let getUserEntitlements = "get_user_entitlements"
        public static let checkFeatureLimit = "check_feature_limit"
        public static let syncStartupAnnouncement = "sync_startup_announcement"
        public static let reconcileQuickFeedbackRequests = "reconcile_quick_feedback_requests"
        public static let createQuickFeedbackRequest = "create_quick_feedback_request"
        public static let claimQuickFeedbackRequest = "claim_quick_feedback_request"
        public static let submitQuickFeedbackReview = "submit_quick_feedback_review"
        public static let closeQuickFeedbackRequest = "close_quick_feedback_request"
    }

    public enum EdgeFunction {
        public static let verifyReceipt = "verify-receipt"
    }
}
