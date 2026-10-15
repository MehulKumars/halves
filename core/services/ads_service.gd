class_name AdsService
extends Node
## Interface for ad providers. Game code calls Services.ads, never a plugin directly.
## Implementations: MockAdsService (editor and PC). Add an AdMob implementation when a
## game needs real ads, and choose it in services.gd.
## Where interstitials may show is decided by AdPolicy, not here.

signal rewarded_finished(placement: String, granted: bool)
signal interstitial_closed(placement: String)


func initialize() -> void:
	pass


func is_rewarded_ready(_placement: String) -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_finished.emit(placement, false)


func is_interstitial_ready(_placement: String) -> bool:
	return false


func show_interstitial(placement: String) -> void:
	interstitial_closed.emit(placement)
