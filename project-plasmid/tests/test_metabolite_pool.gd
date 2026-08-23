## F01-M01 — the immature metabolite pool. Spec §2.1, §2.5.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func test_metabolite_matures_after_maturation_age_ticks() -> void:
	var pool := MetabolitePool.new()
	pool.add(1)
	for i in range(Balance.MATURATION_AGE - 1):
		runner.check_eq(pool.advance(), 0, "matured early, at age %d" % (i + 1))
	runner.check_eq(pool.advance(), 1, "did not mature at age %d" % Balance.MATURATION_AGE)
	runner.check_eq(pool.available(), 0, "a matured metabolite stayed in the pool")


func test_spending_takes_youngest_first() -> void:
	var pool := MetabolitePool.new()
	pool.add(2)
	pool.advance()      # the first two are now age 1
	pool.add(3)         # these three are age 0

	runner.check(pool.try_spend(3), "a pool of 5 could not cover a spend of 3")
	# The nearly-matured pair must survive; §2.1 exists so players never feel robbed
	# of metabolites that were about to bank.
	runner.check_eq(pool.available(), 2, "wrong amount left in the pool")
	runner.check_eq(pool.count_at_age(0), 0, "left younger metabolites behind")
	runner.check_eq(pool.count_at_age(1), 2, "spent the older metabolites instead")


func test_spending_crosses_into_older_buckets_only_once_younger_are_gone() -> void:
	var pool := MetabolitePool.new()
	pool.add(2)
	pool.advance()      # two at age 1
	pool.add(1)         # one at age 0

	runner.check(pool.try_spend(2), "a pool of 3 could not cover a spend of 2")
	runner.check_eq(pool.count_at_age(0), 0, "youngest was not taken first")
	runner.check_eq(pool.count_at_age(1), 1, "should have taken exactly one older metabolite")


func test_spend_is_all_or_nothing() -> void:
	var pool := MetabolitePool.new()
	pool.add(2)
	runner.check(not pool.try_spend(3), "overspend was allowed")
	runner.check_eq(pool.available(), 2, "a failed spend still took metabolites")


func test_empty_pool_stalls_rather_than_going_negative() -> void:
	var pool := MetabolitePool.new()
	runner.check(not pool.try_spend(1), "spent from an empty pool")
	runner.check_eq(pool.available(), 0, "empty pool went negative")


func test_clone_is_independent_of_its_original() -> void:
	var pool := MetabolitePool.new()
	pool.add(4)
	var copy: MetabolitePool = pool.clone()

	copy.try_spend(4)
	runner.check_eq(pool.available(), 4, "clone shares its buckets with the original")
	runner.check_eq(copy.available(), 0, "clone did not spend")
