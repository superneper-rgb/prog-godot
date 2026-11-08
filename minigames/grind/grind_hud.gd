class_name GrindHud
extends Control
## RAILJACK's HUD at full resolution, inside the glass (JS drawHud, drawScope, drawResult, text, tag, blocks).

var S: GrindSession = null
var _font: Font = null


func _ready() -> void:
	_font = CrtTheme.font(&"vt323")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rgba(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


func _width(s: String, size: int, sp: float) -> float:
	var w := 0.0
	for i in s.length():
		w += _font.get_char_size(s.unicode_at(i), size).x + sp
	return w


func text(s: String, x: float, y: float, size: float, col: Color, a: float = 1.0, align: String = "left", spacing: float = 0.06) -> float:
	var sz := roundi(size)
	var sp := roundf(size * spacing)
	var wd := _width(s, sz, sp)
	var x0 := x
	if align == "center":
		x0 = x - wd / 2.0
	elif align == "right":
		x0 = x - wd
	var rid := get_canvas_item()
	# c.shadowBlur = size * 0.4: two soft outlines under the fill
	var o1 := maxi(2, roundi(size * 0.36))
	var o2 := maxi(1, roundi(size * 0.16))
	var c1 := _rgba(col, 0.16 * a)
	var c2 := _rgba(col, 0.28 * a)
	var c3 := _rgba(col, a)
	var cx := x0
	for i in s.length():
		var ch := s.unicode_at(i)
		if ch != 32:
			_font.draw_char_outline(rid, Vector2(cx, y), ch, sz, o1, c1)
			_font.draw_char_outline(rid, Vector2(cx, y), ch, sz, o2, c2)
		cx += _font.get_char_size(ch, sz).x + sp
	cx = x0
	for i in s.length():
		var ch := s.unicode_at(i)
		_font.draw_char(rid, Vector2(cx, y), ch, sz, c3)
		cx += _font.get_char_size(ch, sz).x + sp
	return wd


func tag(s: String, x: float, y: float, size: float, col: Color, a: float = 1.0, align: String = "left") -> float:
	var sz := roundi(size)
	var sp := roundf(size * 0.1)
	var tw := _width(s, sz, sp)
	var pad := size * 0.3
	var x0 := x
	if align == "right":
		x0 = x - tw - pad * 2.0
	elif align == "center":
		x0 = x - tw / 2.0 - pad
	var r := Rect2(x0, y - size * 0.8, tw + pad * 2.0, size * 1.02)
	draw_rect(r.grow(size * 0.28), _rgba(col, 0.1 * a))      # c.shadowBlur = size * 0.5
	draw_rect(r.grow(size * 0.13), _rgba(col, 0.18 * a))
	draw_rect(r, _rgba(col, a))
	var rid := get_canvas_item()
	var ink := Color(2 / 255.0, 14 / 255.0, 6 / 255.0, a)
	var cx := x0 + pad
	for i in s.length():
		var ch := s.unicode_at(i)
		_font.draw_char(rid, Vector2(cx, y), ch, sz, ink)
		cx += _font.get_char_size(ch, sz).x + sp
	return tw + pad * 2.0


func blocks(x: float, y: float, n: int, filled: int, bw: float, bh: float, col: Color, a: float) -> void:
	for i in n:
		draw_rect(Rect2(x + i * bw, y, bw * 0.72, bh), _rgba(col if i < filled else S.COL.gap, a if i < filled else 0.5 * a))


static func fmt_time(s: float) -> String:
	var m := floori(s / 60.0)
	return "%02d:%04.1f" % [m, s - m * 60.0]


func _draw() -> void:
	if S == null:
		return
	var COL := S.COL
	var X := 0.0
	var Y := 0.0
	var W := size.x
	var H := size.y
	var u := H / 520.0
	var t := Time.get_ticks_msec() / 1000.0
	var m := 26.0 * u
	var R := X + W - m
	var B := Y + H - m
	var L := X + m
	var T := Y + m
	if S.phase == "boot":
		draw_rect(Rect2(X, Y, W, H), Color(1 / 255.0, 6 / 255.0, 3 / 255.0, 0.82))
		var left := floori(S.pt * 110.0)
		var yy := T + 34.0 * u
		var last := Vector2.ZERO
		var has_last := false
		for ln: String in S.boot_lines():
			if left <= 0:
				break
			var s := ln.substr(0, left)
			left -= maxi(1, ln.length())
			last = Vector2(L + 10.0 * u + text(s, L + 10.0 * u, yy, 25.0 * u, COL.white if s.begins_with("C:") else COL.solid, 0.95), yy)
			has_last = true
			yy += 29.0 * u
		if has_last and sin(t * 9.0) > 0.0:
			draw_rect(Rect2(last.x + 3.0 * u, last.y - 18.0 * u, 12.0 * u, 20.0 * u), _rgba(COL.solid, 0.9))
		text("- PRESS ANY KEY -", X + W / 2.0, B, 20.0 * u, COL.dim, 0.5 + 0.4 * sin(t * 6.0), "center")
		return
	# header
	var tw := tag("RAILJACK", L, T + 16.0 * u, 18.0 * u, COL.solid, 0.9)
	var uw := text("UPLINK", L + tw + 10.0 * u, T + 16.0 * u, 18.0 * u, COL.dim, 0.8)
	text("C:\\> " + S.title + ("_" if sin(t * 6.0) > 0.0 else ""), L, T + 46.0 * u, 30.0 * u, COL.white, 0.95, "left", 0.08)
	text("SCORE %07d   ICE %s" % [roundi(S.score_shown), String(S.tier.name)], L, T + 70.0 * u, 20.0 * u, COL.dim, 0.85)
	# trace meter
	var tr := clampf(S.trace, 0.0, 100.0)
	var tcol: Color = COL.solid if tr < 50.0 else (COL.fire if tr < 75.0 else COL.red)
	var blink := tr > 80.0 and sin(t * 14.0) < 0.0
	var segs := 20
	var bw := 9.0 * u
	var bx := R - segs * bw
	tag("TRACE", bx - 8.0 * u, T + 16.0 * u, 18.0 * u, tcol, 0.45 if blink else 0.95, "right")
	blocks(bx, T + 2.0 * u, segs, ceili(tr / 100.0 * segs), bw, 16.0 * u, tcol, 0.45 if blink else 0.95)
	text("%d%%   T+%s" % [floori(tr), fmt_time(S.time)], R, T + 44.0 * u, 22.0 * u, tcol, 0.9, "right")
	if tr > 75.0 and S.phase == "play" and sin(t * 9.0) > -0.2:
		tag("!! TRACE IMMINENT - DISCONNECT ADVISED !!", X + W / 2.0, T + 104.0 * u, 19.0 * u, COL.red, 0.95, "center")
	# upload progress: the rest of the header line, up to the trace meter
	var prog := clampf(S.p.z / S.gate_z, 0.0, 1.0)
	var ux := L + tw + uw + 24.0 * u
	var lw := text("UPLOAD %3d%%" % floori(prog * 100.0), ux, T + 16.0 * u, 18.0 * u, COL.white, 0.9)
	var px := ux + lw + 10.0 * u
	var pw := bx - 100.0 * u - px
	if pw > 30.0 * u:
		draw_rect(Rect2(px, T + 4.0 * u, pw, 12.0 * u), _rgba(COL.solid, 0.7), false, 1.2 * u)
		draw_rect(Rect2(px + 2.0 * u, T + 6.0 * u, (pw - 4.0 * u) * prog, 8.0 * u), _rgba(COL.solid, 0.85))
	# EOF warning: the line under you is about to run out
	if S.eof != GrindSession.NONE and S.phase == "play" and sin(t * 16.0) > -0.3:
		var lt := ""
		var rt := ""
		for l: int in [-1, 0, 1]:
			if l != S.p.lane and S.rail_at(l, S.eof + 4.0):
				if l < S.p.lane:
					lt = "<<  "
				if l > S.p.lane:
					rt = "  >>"
		tag(" " + lt + "EOF - SWITCH LINES" + rt + " ", X + W / 2.0, Y + H * 0.36, 26.0 * u, COL.fire, 0.95, "center")
	# footer: speed as a modem rate, bits, the lane scope, controls
	var bps := roundi(S.v * 1067.0 / 100.0) * 100
	tag("CARRIER", L, B - 26.0 * u, 17.0 * u, COL.solid, 0.85)
	text("%05d BPS" % bps, L + 84.0 * u, B - 26.0 * u, 22.0 * u, COL.white, 0.9)
	text("BITS %03d" % S.nbits + ("   STREAK x%d" % mini(S.streak, 8) if S.streak >= 2 else ""), L + 210.0 * u, B - 26.0 * u, 20.0 * u, COL.key, 0.85)
	if S.chain >= 2 and S.phase == "play":      # clean-pass chain, top centre: grows and warms up as it climbs
		var k := minf(1.0, S.chain / 15.0)
		var pul := 1.0 + 0.08 * sin(t * 12.0) * k
		tag(" CLEAN CHAIN x%d " % S.chain, X + W / 2.0, Y + 70.0 * u, snappedf((22.0 + 14.0 * k) * u * pul, 2.0), COL.fire if S.chain >= 10 else COL.probe, 0.95, "center")
	if S.oc > 0.0:
		draw_rect(Rect2(X + 3.0 * u, Y + 3.0 * u, W - 6.0 * u, H - 6.0 * u), _rgba(COL.fire, 0.35 + 0.25 * sin(t * 14.0)), false, 6.0 * u)
		tag(" OVERCLOCK %.1fs " % S.oc, X + W / 2.0, Y + H * 0.2, 26.0 * u, COL.fire, 0.95, "center")
	draw_scope(R - 96.0 * u, B - 150.0 * u, 96.0 * u, 138.0 * u, u)
	var hint := "D-PAD HOP  A JUMP  B SHRINK  BACK ABORT" if S.pad else "A/D HOP  SPACE JUMP  S/SHIFT SHRINK  ESC ABORT"
	if S.phase == "play" or S.phase == "count" or S.phase == "lost":
		text(hint, L, B - 4.0 * u, 16.0 * u, COL.dim, 0.55)
	# popups float up from the packet
	var kx := W / S.view.W
	var ky := H / S.view.H
	for q: Dictionary in S.popups:
		text(q.text, X + float(q.x) * kx, Y + float(q.y) * ky - 20.0 * u - float(q.t) * 50.0 * u, 19.0 * u, q.col, 1.0 - float(q.t) / 1.1, "center")
	if S.phase == "count":
		var n := 3 - floori(S.pt / 0.55)
		var fr := fmod(S.pt, 0.55) / 0.55
		if n > 0:
			tag(" SYNC %d " % n, X + W / 2.0, Y + H * 0.42, snappedf((52.0 + 20.0 * (1.0 - fr)) * u, 2.0), COL.solid, 1.0 - fr * 0.5, "center")
	if not S.banner.is_empty():
		var bn := S.banner
		var bt: float = bn.t
		var bd: float = bn.dur
		var a := clampf(minf(bt / 0.12, (bd - bt) / 0.4), 0.0, 1.0) * (0.3 if bt < 0.3 and sin(bt * 80.0) < 0.0 else 1.0)
		tag(" " + String(bn.text) + " ", X + W / 2.0, Y + H * 0.29, 40.0 * u, bn.col, a, "center")
		if String(bn.sub) != "":
			text(bn.sub, X + W / 2.0, Y + H * 0.29 + 34.0 * u, 20.0 * u, COL.white, a * 0.85, "center")
	if S.phase == "win" and S.pt > 0.35:
		tag(" UPLOAD COMPLETE ", X + W / 2.0, Y + H * 0.5, 50.0 * u, COL.white, clampf((S.pt - 0.35) * 3.0, 0.0, 1.0), "center")
	if S.phase == "fail":
		tag(" TRACE COMPLETE ", X + W / 2.0, Y + H * 0.5, 50.0 * u, COL.red, 1.0 if sin(t * 20.0) > -0.3 else 0.3, "center")
	if S.phase == "result":
		draw_result(X, Y, W, H, u, t)


## LANE SCOPE: the next three seconds of line, top-down, like a sonar strip
func draw_scope(x: float, y: float, w: float, h: float, u: float) -> void:
	var COL := S.COL
	var p := S.p
	var span := S.v * 3.0
	draw_rect(Rect2(x, y, w, h), Color(1 / 255.0, 10 / 255.0, 4 / 255.0, 0.75))
	draw_rect(Rect2(x, y, w, h), _rgba(COL.solid, 0.55), false, 1.0 * u)
	text("SCOPE", x + 4.0 * u, y - 4.0 * u, 14.0 * u, COL.dim, 0.75)
	var clip := Rect2(x, y, w, h)
	for k in range(1, 3):
		draw_rect(Rect2(x, y + h * k / 3.0, w, 1.0), _rgba(COL.gap, 0.4))
	for l in range(-1, 2):
		var col_x := x + (l + 1.5) * w / 3.0
		for s: GrindSession.Rail in S.rails[l + 1]:
			if s.z1 < p.z or s.z0 > p.z + span:
				continue
			var y0 := y + h - (minf(s.z1, p.z + span) - p.z) / span * h
			var y1 := y + h - (maxf(s.z0, p.z) - p.z) / span * h
			draw_rect(Rect2(col_x - 1.2 * u, y0, 2.4 * u, y1 - y0).intersection(clip), _rgba(COL.white if l == p.lane else COL.solid, 0.85))
			if s.z1 < p.z + span:
				draw_rect(Rect2(col_x - 6.0 * u, y0 - 1.5 * u, 12.0 * u, 3.0 * u).intersection(clip), _rgba(COL.fire, 0.95))
	for i in range(S._ob_i, S.obs.size()):
		var o := S.obs[i]
		if o.z < p.z or o.hit:
			continue
		if o.z > p.z + span:
			break
		var cx := x + (o.lane + 1.5) * w / 3.0
		var cy := y + h - (o.z - p.z) / span * h
		var cc: Color = _rgba(COL.red if o.type == &"runner" else COL.fire, 0.95)
		if o.type == &"wall":
			draw_rect(Rect2(cx - 10.0 * u, cy - 6.0 * u, 20.0 * u, 12.0 * u).intersection(clip), cc)
		elif o.type == &"low":
			draw_rect(Rect2(cx - 9.0 * u, cy - 1.5 * u, 18.0 * u, 3.0 * u).intersection(clip), cc)
		elif o.type == &"high":
			draw_rect(Rect2(cx - 9.0 * u, cy - 1.5 * u, 18.0 * u, 3.0 * u).intersection(clip), cc)
			draw_rect(Rect2(cx - 9.0 * u, cy - 5.0 * u, 3.0 * u, 6.0 * u).intersection(clip), cc)
			draw_rect(Rect2(cx + 6.0 * u, cy - 5.0 * u, 3.0 * u, 6.0 * u).intersection(clip), cc)
		else:
			draw_circle(Vector2(cx, clampf(cy, y, y + h)), 4.0 * u, cc)
	var px := x + (p.x / GrindSession.LANE_W + 1.5) * w / 3.0
	var py := y + h - 4.0 * u
	draw_primitive(PackedVector2Array([Vector2(px, py - 9.0 * u), Vector2(px + 6.0 * u, py), Vector2(px - 6.0 * u, py)]), PackedColorArray([_rgba(COL.white, 0.95)]), PackedVector2Array())


func draw_result(X: float, Y: float, W: float, H: float, u: float, t: float) -> void:
	var COL := S.COL
	var r := S.result
	var a := clampf(S.pt * 4.0, 0.0, 1.0)
	var cw := minf(W - 60.0 * u, 470.0 * u)
	var ch := 372.0 * u
	var x := X + (W - cw) / 2.0
	var y := Y + (H - ch) / 2.0
	var col: Color = COL.solid if r.ok else COL.red
	draw_rect(Rect2(x, y, cw, ch), Color(1 / 255.0, 8 / 255.0, 3 / 255.0, 0.9 * a))
	draw_rect(Rect2(x, y, cw, ch), _rgba(col, 0.85 * a), false, 1.5 * u)
	draw_rect(Rect2(x + 5.0 * u, y + 5.0 * u, cw - 10.0 * u, ch - 10.0 * u), _rgba(col, 0.85 * a), false, 1.5 * u)
	tag(" UPLOAD COMPLETE " if r.ok else " LOCKOUT ", x + cw / 2.0, y + 52.0 * u, 40.0 * u, col, a, "center")
	text(S.title, x + cw / 2.0, y + 86.0 * u, 20.0 * u, COL.white, a * 0.75, "center")
	var rows: Array = [["SCORE", "%07d" % int(r.score)], ["ELAPSED", fmt_time(r.time)], ["BITS", "%03d" % int(r.bits)], ["BEST CHAIN", "x%d" % int(r.best_chain)], ["ICE CONTACTS", "%02d" % int(r.contacts)], ["PACKETS LOST", "%02d" % int(r.falls)], ["FINAL TRACE", "%d%%" % int(r.trace) + ("  +%d" % int(r.trace_bonus) if int(r.trace_bonus) != 0 else "")]]
	for i in rows.size():
		var yy := y + 122.0 * u + i * 27.0 * u
		var k: String = rows[i][0]
		text(k + " " + ".".repeat(16 - k.length()), x + 34.0 * u, yy, 23.0 * u, col, a * 0.85)
		text(rows[i][1], x + 264.0 * u, yy, 23.0 * u, COL.white, a)
	if r.ok:
		text("GRADE", x + cw - 62.0 * u, y + 128.0 * u, 18.0 * u, COL.dim, a, "center")
		text(r.rating, x + cw - 62.0 * u, y + 200.0 * u, 76.0 * u, COL.white, a, "center")
	if S.pt > 0.6:
		text(("[A]" if S.pad else "[ENTER]") + " CONTINUE", x + cw / 2.0, y + ch - 20.0 * u, 19.0 * u, COL.white, 0.5 + 0.4 * sin(t * 6.0), "center")
