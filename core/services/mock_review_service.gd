class_name MockReviewService
extends ReviewService
## Prints instead of showing the Play in-app review sheet.


func request_review() -> void:
	print("[MockReview] review requested")
