extends Node
## Service hub (autoload "Services"): the only place that knows which implementation is live.
## Game code calls, for example:
##   Services.ads.show_rewarded("revive")
##   Services.analytics.log_event("first_win", {"level": 1})
## Never call a plugin singleton (AdMob, Billing, Play Games) from anywhere else.

var ads: AdsService
var iap: IAPService
var analytics: AnalyticsService
var leaderboard: LeaderboardService
var review: ReviewService


func _ready() -> void:
	# Real Android implementations are added here as each plugin is installed, e.g.
	# `ads = _add(AdMobAdsService.new() if OS.get_name() == "Android" else MockAdsService.new(), "Ads")`.
	# Until then every platform uses mocks, so the whole game loop is playable on PC.
	ads = _add(MockAdsService.new(), "Ads") as AdsService
	iap = _add(MockIAPService.new(), "IAP") as IAPService
	analytics = _add(MockAnalyticsService.new(), "Analytics") as AnalyticsService
	leaderboard = _add(MockLeaderboardService.new(), "Leaderboard") as LeaderboardService
	review = _add(MockReviewService.new(), "Review") as ReviewService

	ads.initialize()
	iap.initialize()
	analytics.initialize()
	leaderboard.initialize()
	review.initialize()


func _add(service: Node, service_name: String) -> Node:
	service.name = service_name
	add_child(service)
	return service
