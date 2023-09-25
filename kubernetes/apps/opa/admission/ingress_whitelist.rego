package kubernetes.admission

whitelist = [
	"*.dev.acmecorp.com",
	"*.test.acmecorp.com",
]

deny[msg] {
	input.request.kind.kind == "Ingress"
	input.request.operation == "CREATE"
	input.request.namespace == "opa"
	host := input.request.object.spec.rules[_].host
	not glob_match_one_of(whitelist, host)
	msg := sprintf("ingress host %q is invalid", [host])
}

glob_match_one_of(patterns, str) {
	glob.match(patterns[_], ["."], str)
}
