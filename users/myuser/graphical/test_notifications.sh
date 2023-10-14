#!/usr/bin/env bash

short_summary=("Short summary")
long_summary=("Long summary, it will be truncated because it is really really long")

short_body=("Short body.")
long_body=("Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.")

app_discord=(
	"--app-name=Discord"
	"--icon=/run/current-system/etc/profiles/per-user/$USER/share/pixmaps/discord.png"
)

image_1=("--hint=string:image-path:$HOME/Downloads/wallpaper.png")

urgency_low=("--urgency=low")
urgency_normal=("--urgency=normal")
urgency_critical=("--urgency=critical")

slider_0=("-h" "int:value:0")
slider_25=("-h" "int:value:25")
slider_100=("-h" "int:value:100")

actions_yes_no=("-A" "yes" "-A" "no")
actions_5=("-A" "yes" "-A" "no" "-A" "maybe" "-A" "cancel" "-A" "very long name is truncated")

function show() {
	args=()
	while [[ $# -gt 0 ]]; do
		if [[ -v "$1" ]]; then
			x="$1[@]"
			args+=("${!x}")
		else
			args+=("$1")
		fi
		shift
	done
	notify-send "${args[@]}"
}

show short_summary
show long_summary
show long_summary  long_body

show "Low urgency" short_body urgency_low
show "Normal urgency" short_body urgency_normal
show "Critical urgency" short_body urgency_critical

show "With app icon and name"            app_discord
show "With app icon and name" long_body  app_discord

show "With image"          short_body image_1
show "With image and body" long_body image_1

show "With progress"                     slider_0
show "With progress"                     slider_25
show "With progress and body" short_body slider_100

show "With buttons"                    actions_yes_no
show "With buttons and body" long_body actions_5

show "With everything" long_body app_discord image_1 slider_25 actions_5

#for summary in \
#	"Short summary" \
#	"Long summary, it will be truncated because it is really really long" \
#; do
#
#for body in \
#	"Short body." \
#	"$lorem" \
#; do
#
#for app in \
#	"empty[@]" \
#	"app_discord[@]" \
#; do
#
#for image in \
#	"empty[@]" \
#	"image_1[@]" \
#; do
#
#for urgency in \
#	"urgency_low[@]" \
#	"urgency_normal[@]" \
#	"urgency_critical[@]" \
#; do
#
#for progress in \
#	"empty[@]" \
#	"slider_0[@]" \
#	"slider_25[@]" \
#	"slider_100[@]" \
#; do
#
#for action in \
#	"empty[@]" \
#; do
#	#"actions_yes_no[@]" \
#	#"actions_5[@]" \
#
#notify-send "$summary" "$body" \
#	"${!app}" \
#	"${!image}" \
#	"${!progress}" \
#	"${!action}" \
#	"${!urgency}" \
#	;
#
#done
#done
#done
#done
#done
#done
#done
