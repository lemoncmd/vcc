module ast

pub struct ScopeTable {
pub:
	parent int
pub mut:
	types    map[string]Type
	storages map[string]Storage
	offset   map[string]int
}
