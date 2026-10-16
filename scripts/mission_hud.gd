extends Control
## Presentation only: contextual prompts, compact objective, optional paused map.
const MAP = preload("res://scripts/mission_map.gd")
const INK := Color("101c23")
const PAPER := Color("ded8c5")
const MUTED := Color("8caaa8")
const AMBER := Color("d9ae70")
const SIGNAL := Color("d87965")
var mission: Node3D
var objective: Label
var status: Label
var prompt: Label
var exposure_bar: ProgressBar
var interaction_bar: ProgressBar
var map: Control
var overlay: ColorRect
var title: Label
var briefing: Label
var start_button: Button
var _pause: PanelContainer
var _title_card: Label
var _step := -1
var _step_clock := 0.0
var _current_marker := Vector2(-100, -100)
var _has_marker := false
var _credits: ColorRect
var _cover_menu: Button
var _credits_close: Button
const INTRO_TEXT := "02:17. O cais fecha antes do amanhecer.\nUm pacote ficou no Armazém 07. Você sabe o caminho de volta.\n\nSiga a rua de serviço pelo lado do Café Maré.\nAgache atrás das cargas e espere o vigia passar.\nRecupere a entrega. Quando o alarme tocar, saia e monte no skate.\nO atalho da oficina leva à extração no Cais Norte."

func label(parent: Node, text: String, font_size: int, color := PAPER) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", color)
    node.add_theme_color_override("font_shadow_color", Color(0.015, 0.025, 0.03, 0.9))
    node.add_theme_constant_override("shadow_offset_y", 1)
    node.mouse_filter = MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node

func flat(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1 if border.a > 0 else 0)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func bar(parent: Node, width: float, color: Color) -> ProgressBar:
    var node := ProgressBar.new()
    node.custom_minimum_size = Vector2(width, 3)
    node.max_value = 1.0
    node.show_percentage = false
    node.add_theme_stylebox_override("background", thin(Color(0.1, 0.16, 0.18, 0.65)))
    node.add_theme_stylebox_override("fill", thin(color))
    parent.add_child(node)
    return node

func thin(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_content_margin_all(0)
    return style

func _ready() -> void:
    set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    mouse_filter = MOUSE_FILTER_IGNORE
    # Cheap UI gradients, no screen-texture read or full-screen post-processing.
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color(0.015, 0.028, 0.035, 0.7), Color.TRANSPARENT])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill_from = Vector2(0, 0)
    texture.fill_to = Vector2(0, 1)
    var fade := TextureRect.new()
    fade.texture = texture
    fade.mouse_filter = MOUSE_FILTER_IGNORE
    add_child(fade)
    fade.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
    fade.offset_bottom = 148
    var left := VBoxContainer.new()
    left.position = Vector2(32, 28)
    left.add_theme_constant_override("separation", 5)
    add_child(left)
    label(left, "N I G H T S H I F T    /    RUA 01", 12, MUTED)
    objective = label(left, "Armazém 07", 22)
    var alert := VBoxContainer.new()
    add_child(alert)
    alert.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
    alert.offset_left = -100
    alert.offset_right = 100
    alert.offset_top = 35
    status = label(alert, "", 14, AMBER)
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    exposure_bar = bar(alert, 200, AMBER)
    var interaction := VBoxContainer.new()
    add_child(interaction)
    interaction.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
    interaction.offset_left = -280
    interaction.offset_right = 280
    interaction.offset_top = -86
    interaction.offset_bottom = -36
    prompt = label(interaction, "", 18)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interaction_bar = bar(interaction, 300, MUTED)
    interaction_bar.size_flags_horizontal = SIZE_SHRINK_CENTER
    _title_card = label(self, "", 14, MUTED)
    _title_card.position = Vector2(32, 84)
    map = MAP.new()
    map.mission = mission
    add_child(map)
    map.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
    map.offset_left = -242
    map.offset_right = -32
    map.offset_top = 32
    map.offset_bottom = 328
    map.mouse_filter = MOUSE_FILTER_IGNORE
    _pause = PanelContainer.new()
    _pause.add_theme_stylebox_override("panel", flat(Color(0.025, 0.045, 0.055, 0.96), Color("526a6c")))
    add_child(_pause)
    _pause.set_anchors_and_offsets_preset(PRESET_CENTER)
    _pause.offset_left = -245
    _pause.offset_right = 245
    _pause.offset_top = -140
    var help := VBoxContainer.new()
    help.add_theme_constant_override("separation", 15)
    _pause.add_child(help)
    label(help, "ENTRE UMA ENTREGA E OUTRA", 20)
    label(help, "WASD mover  ·  Shift correr  ·  Espaço pular\nC / Ctrl agachar  ·  Segure E para interagir\nF subir / descer do skate\nSkate: W acelerar  ·  A/D virar  ·  S / Espaço frear\nMouse câmera  ·  R recentrar  ·  M trilha sonora", 16, MUTED)
    var resume := Button.new()
    resume.text = "CONTINUAR   /   ESC"
    resume.add_theme_stylebox_override("normal", flat(INK, MUTED))
    resume.pressed.connect(func(): mission.player.camera_rig.set_mouse_captured(true))
    help.add_child(resume)
    menu_button(help, "REINICIAR ENTREGA", mission.start_mission)
    menu_button(help, "MENU INICIAL", mission.show_main_menu)
    menu_button(help, "SAIR DO JOGO", func(): get_tree().quit())
    _build_cover()
    _build_credits()
    refresh()

func menu_button(parent: Node, text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.add_theme_stylebox_override("normal", flat(INK, MUTED))
    button.add_theme_stylebox_override("hover", flat(Color("29413f"), AMBER))
    button.add_theme_stylebox_override("focus", flat(INK, AMBER))
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func show_intro() -> void:
    title.text = "NIGHTSHIFT"
    briefing.text = INTRO_TEXT
    start_button.text = "INICIAR ENTREGA   [ENTER]"
    start_button.disabled = not mission.ready_to_start

func _build_cover() -> void:
    overlay = ColorRect.new()
    overlay.color = Color(0.018, 0.035, 0.043, 0.97)
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    var margin := MarginContainer.new()
    overlay.add_child(margin)
    margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 78)
    margin.add_theme_constant_override("margin_right", 78)
    margin.add_theme_constant_override("margin_top", 50)
    margin.add_theme_constant_override("margin_bottom", 40)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 16)
    margin.add_child(content)
    label(content, "CAIS NORTE     /     02:17     /     CHUVA", 13, MUTED)
    title = label(content, "NIGHTSHIFT", 70)
    label(content, "Ú L T I M A   E N T R E G A", 17, AMBER)
    var rule := HSeparator.new()
    rule.add_theme_stylebox_override("separator", thin(Color("506763")))
    content.add_child(rule)
    briefing = label(content, INTRO_TEXT, 20)
    var space := Control.new()
    space.size_flags_vertical = SIZE_EXPAND_FILL
    content.add_child(space)
    label(content, "WASD mover    /    Espaço pular    /    C · CTRL agachar    /    E interagir    /    F skate", 14, MUTED)
    start_button = Button.new()
    start_button.text = "PREPARANDO A RUA…"
    start_button.disabled = true
    start_button.custom_minimum_size = Vector2(330, 52)
    start_button.size_flags_horizontal = SIZE_SHRINK_BEGIN
    start_button.add_theme_font_size_override("font_size", 19)
    for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
        start_button.add_theme_color_override(state, INK)
    start_button.add_theme_stylebox_override("normal", flat(PAPER))
    start_button.add_theme_stylebox_override("hover", flat(Color("e0b97c")))
    start_button.add_theme_stylebox_override("focus", flat(Color.TRANSPARENT, AMBER))
    start_button.pressed.connect(mission.start_mission)
    content.add_child(start_button)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 18)
    content.add_child(actions)
    menu_button(actions, "CRÉDITOS", func():
        _credits.visible = true
        _credits_close.grab_focus())
    _cover_menu = menu_button(actions, "MENU INICIAL", mission.show_main_menu)
    _cover_menu.visible = false
    menu_button(actions, "SAIR", func(): get_tree().quit())

func _build_credits() -> void:
    _credits = ColorRect.new()
    _credits.color = Color("101d23")
    add_child(_credits)
    _credits.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    var margin := MarginContainer.new()
    _credits.add_child(margin)
    margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 54)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    margin.add_child(column)
    label(column, "NIGHTSHIFT  /  CRÉDITOS", 28, AMBER)
    var text := RichTextLabel.new()
    text.text = FileAccess.get_file_as_string("res://CREDITS.txt")
    text.size_flags_vertical = SIZE_EXPAND_FILL
    text.add_theme_font_size_override("normal_font_size", 18)
    column.add_child(text)
    _credits_close = menu_button(column, "VOLTAR", func():
        _credits.visible = false
        start_button.grab_focus())
    _credits.visible = false

func refresh() -> void:
    var running: bool = mission.phase == "RUNNING"
    var paused: bool = running and not mission.player.camera_rig.mouse_captured
    _cover_menu.visible = mission.phase in ["WON", "LOST"]
    map.visible = paused
    _pause.visible = paused
    var step: int = 2 if mission.has_package else (1 if mission.door_open else 0)
    if step != _step:
        _step = step
        _step_clock = 5.0
    var destination: Vector3 = mission.alternate_exit if step == 2 else (mission.package_point if step == 1 else mission.entry_point)
    var distance: float = mission.player.position.distance_to(destination)
    objective.text = ["Entre no Armazém 07", "Recolha o pacote", "Extração / Cais Norte"][step] + "   /   %d m" % int(distance)
    objective.visible = running
    _title_card.text = ["Rota do Café Maré / Esc abre o mapa", "A carga é sua", "Use F e fuja pelo atalho da oficina"][step]
    _title_card.visible = running and _step_clock > 0 and not paused
    var suspicion: float = mission.exposure()
    var searching := false
    var watched := false
    for guard in mission.guards:
        searching = searching or guard.state == "SEARCH" or guard.state == "INVESTIGATE"
        watched = watched or (guard.sees_player and guard.suspicion > 0.025)
    var chased: bool = mission.is_chased()
    status.text = ("ALARME  /  FUJA" if mission.escape_alarm_time > 0 else "!  DESPISTE") if chased else ("?  OBSERVADO" if watched else ("BUSCANDO VOCÊ" if searching else ""))
    var color := SIGNAL if chased else AMBER
    status.add_theme_color_override("font_color", color)
    exposure_bar.add_theme_stylebox_override("fill", thin(color))
    exposure_bar.value = suspicion
    exposure_bar.visible = running and not paused and suspicion > 0.025
    status.visible = running and not paused and (suspicion > 0.025 or searching)
    prompt.text = ""
    var kind: String = mission._interaction()
    if chased and distance < 2.2 and step < 2:
        prompt.text = "Despiste os vigias antes de interagir"
    elif mission.door_opening and step == 0 and distance < 3.5:
        prompt.text = "Abrindo acesso…"
    elif kind != "":
        prompt.text = "Segure E   /   " + ("Abrir acesso" if kind == "DOOR" else "Recolher pacote")
        if suspicion >= 0.55:
            prompt.text = "Espere o alerta baixar"
    elif mission.player.mount_hint != "":
        prompt.text = mission.player.mount_hint
    elif distance < (9.0 if step == 2 else 2.2):
        if step == 2:
            prompt.text = "F   /   Skate para a saída" if not mission.player.is_skating else ("Despiste os vigias" if chased else "W   /   Ganhe velocidade e atravesse a saída")
        elif mission.player.is_skating:
            prompt.text = "F   /   Descer para interagir"
        else:
            prompt.text = "Pare para interagir"
    elif mission.elapsed < 7 and mission.player.position.z < -27:
        prompt.text = "Siga pelo lado do Café Maré   /   C ou Ctrl para se esconder"
    if mission.boundary_time > 0:
        prompt.text = "Volte à Rua 01 / Cais Norte   /   %.0f s" % (6 - mission.boundary_time)
    prompt.visible = running and not paused and prompt.text != ""
    interaction_bar.visible = running and not paused and mission.interaction_progress > 0
    interaction_bar.value = mission.interaction_progress
    _has_marker = false
    # Single small target diamond, occluded by buildings; no floating word cloud.
    var camera: Camera3D = mission.player.get_camera()
    var target := destination + Vector3.UP * (1.1 if step < 2 else 0.2)
    if running and not paused and distance < 30 and not camera.is_position_behind(target):
        var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1)
        var hit := mission.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.is_empty() or hit.position.distance_to(target) < 0.6:
            _current_marker = camera.unproject_position(target)
            _has_marker = true
    if paused:
        map.queue_redraw()
    queue_redraw()

func _process(delta: float) -> void:
    if mission.phase == "RUNNING" and mission.player.camera_rig.mouse_captured:
        _step_clock = maxf(0, _step_clock - delta)
    # Refresh follows the existing mission HUD's 10 Hz tick.

func _draw() -> void:
    if _has_marker:
        var points := PackedVector2Array([Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0), Vector2(0, -5)])
        for index in points.size():
            points[index] += _current_marker
        draw_polyline(points, Color("a9c9ba"), 1.5, true)
