package kubernetes.admission_test

import data.kubernetes.admission

test_allow_outside_example_namespace {
	admission.deny == set() with input as {"request": {
		"operation": "CREATE",
		"kind": {"kind": "Ingress"},
		"namespace": "default",
		"object": {"spec": {"rules": [{"host": "payments.acmecorp.com"}]}},
	}}
}

test_allow_inside_example_namespace {
	admission.deny == set() with input as {"request": {
		"operation": "CREATE",
		"kind": {"kind": "Ingress"},
		"namespace": "opa",
		"object": {"spec": {"rules": [{"host": "payments.dev.acmecorp.com"}]}},
	}}

	admission.deny == set() with input as {"request": {
		"operation": "CREATE",
		"kind": {"kind": "Ingress"},
		"namespace": "opa",
		"object": {"spec": {"rules": [{"host": "payments.test.acmecorp.com"}]}},
	}}
}

test_deny_inside_example_namespace {
	admission.deny["ingress host \"payments.acmecorp.com\" is invalid"] with input as {"request": {
		"operation": "CREATE",
		"kind": {"kind": "Ingress"},
		"namespace": "opa",
		"object": {"spec": {"rules": [{"host": "payments.acmecorp.com"}]}},
	}}
}
