class_name SimEvent
extends RefCounted
## One thing that happened during a tick, recorded as data.
##
## The sim emits these; the plain-language event log (spec §9.3, F03-M04) is a *view*
## over them. Nothing in this file formats a sentence — that is the view's job, and
## keeping it that way is what lets the log be tested and the sim stay pure.
##
## Add new types as milestones land. Every type needs a sentence in the log before
## its feature is done.

enum Type {
	METABOLITE_PRODUCED,
	METABOLITE_MATURED,
	METABOLITE_SPENT,
	SPEND_FAILED,
	## A finished protein took a slot. Carries whether the rack was already full, since
	## expressing into a full rack is the intended teaching moment about waste (§2.3).
	PROTEIN_BUILT,
	## FIFO eviction. Always visible and always logged in plain language (§3.4) — a
	## protein vanishing silently is the most confusing thing this game can do.
	PROTEIN_EVICTED,
	## The environment dripped food into the shared medium (§7.4).
	FOOD_DELIVERED,
	## A membrane transporter moved food inward, paying the workhorse tax (§2.2).
	FOOD_IMPORTED,
	## ...or outward.
	FOOD_EXPORTED,
	## An internal enzyme destroyed a unit of food and yielded metabolites (§2.2).
	FOOD_CATABOLISED,
	## An extracellular enzyme destroyed food in the medium. Pure denial: the metabolites
	## are outside the cell and lost to everyone (§8).
	FOOD_DESTROYED,
	## The battle reached a decided end (§1, §7.0). Emitted by [Battle], not [SimState] —
	## the world does not know it is in a match.
	BATTLE_ENDED,
}

## What happened.
var type: Type

## The tick during which it happened, not the tick that followed it.
var tick: int

## Type-specific payload. Godot dictionaries preserve insertion order, so building
## these in a fixed order keeps the event stream byte-comparable between runs.
var data: Dictionary


func _init(p_type: Type, p_tick: int, p_data: Dictionary = {}) -> void:
	type = p_type
	tick = p_tick
	data = p_data


func _to_string() -> String:
	return "[tick %d] %s %s" % [tick, Type.keys()[type], data]
