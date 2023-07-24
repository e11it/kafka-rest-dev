package kafka.authz

import future.keywords.in

# ----------------------------------------------------
#  Policies
# ----------------------------------------------------

default allow = false


allow {
	sr
}
# ----------------------------------------------------
#  Functions
# ----------------------------------------------------

sr {
	input.requestContext.securityProtocol == "SSL"
	input.requestContext.principal.principalType == "User"
	input.requestContext.principal.name == "sr"
}
