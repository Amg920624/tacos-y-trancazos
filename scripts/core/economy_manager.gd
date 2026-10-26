extends Node
## Autoload "Economy": the single source of truth for money (whole MXN pesos).
## All sales and costs go through here so amounts are always validated.

signal cash_changed(new_cash: int, delta: int)

const MAX_SINGLE_TRANSACTION := 100000

var cash: int = 0
var shift_revenue: int = 0
var shift_costs: int = 0
var shift_cost_items: Dictionary = {}
var total_revenue: int = 0
var total_costs: int = 0
var total_invested: int = 0


func reset(start_cash: int) -> void:
	cash = maxi(0, start_cash)
	shift_revenue = 0
	shift_costs = 0
	shift_cost_items.clear()
	total_revenue = 0
	total_costs = 0
	total_invested = 0
	cash_changed.emit(cash, 0)


func begin_shift() -> void:
	shift_revenue = 0
	shift_costs = 0
	shift_cost_items.clear()


## Validates any incoming amount: rejects non-numbers, NaN, infinities and negatives.
func sanitize(value) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	var f := float(value)
	if is_nan(f) or is_inf(f):
		return 0
	return clampi(int(round(f)), 0, MAX_SINGLE_TRANSACTION)


## Registers a sale. Returns the amount actually accepted (0 if invalid).
func add_sale(amount) -> int:
	var a := sanitize(amount)
	if a <= 0:
		return 0
	cash += a
	shift_revenue += a
	total_revenue += a
	cash_changed.emit(cash, a)
	return a


func can_afford(cost) -> bool:
	var c := sanitize(cost)
	return c <= cash


## Optional purchase: fails (and changes nothing) when funds are insufficient.
func spend(cost, category := "mejoras") -> bool:
	var c := sanitize(cost)
	if c > cash:
		return false
	cash -= c
	if category == "mejoras":
		total_invested += c
	else:
		_record_cost(c, category)
	cash_changed.emit(cash, -c)
	return true


## Mandatory cost (rent, fines). May leave cash negative, which means bankruptcy.
func charge(cost, category := "gastos") -> int:
	var c := sanitize(cost)
	cash -= c
	_record_cost(c, category)
	cash_changed.emit(cash, -c)
	return c


func _record_cost(c: int, category: String) -> void:
	shift_costs += c
	total_costs += c
	shift_cost_items[category] = int(shift_cost_items.get(category, 0)) + c


func is_bankrupt() -> bool:
	return cash < 0


func to_dict() -> Dictionary:
	return {"cash": cash, "total_revenue": total_revenue, "total_costs": total_costs, "total_invested": total_invested}


func from_dict(d: Dictionary) -> void:
	cash = int(d.get("cash", 0))
	total_revenue = maxi(0, int(d.get("total_revenue", 0)))
	total_costs = maxi(0, int(d.get("total_costs", 0)))
	total_invested = maxi(0, int(d.get("total_invested", 0)))
	shift_revenue = 0
	shift_costs = 0
	shift_cost_items.clear()
	cash_changed.emit(cash, 0)


static func money(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out
