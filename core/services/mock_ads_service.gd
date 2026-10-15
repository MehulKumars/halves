class_name MockAdsService
extends AdsService
## Fake ads for the editor and PC: waits briefly, then reports the result.
## Toggle grant_rewards from the dev console with `ads_grant false` to test the "no reward" path.

var simulated_delay_sec: float = 0.5
var grant_rewards: bool = true


func is_rewarded_ready(_placement: String) -> bool:
	return true


func show_rewarded(placement: String) -> void:
	print("[MockAds] rewarded '%s'" % placement)
	await get_tree().create_timer(simulated_delay_sec, true, false, true).timeout
	rewarded_finished.emit(placement, grant_rewards)


func is_interstitial_ready(_placement: String) -> bool:
	return true


func show_interstitial(placement: String) -> void:
	print("[MockAds] interstitial '%s'" % placement)
	await get_tree().create_timer(simulated_delay_sec, true, false, true).timeout
	interstitial_closed.emit(placement)
