#!/bin/bash

# Set environment variables for graphical interface
export DISPLAY=":0"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# Function to display help message
show_help() {
  echo "Usage: $0 --location <city> --api-key <your_api_key> [--output <file>] [--silent] [--help]"
  echo
  echo "Options:"
  echo "  --location <city>    Specify the location for weather information."
  echo "  --api-key <key>      Specify your WeatherAPI key."
  echo "  --output <file>      Save the weather information in JSON format to the specified file."
  echo "  --silent             Suppress all output messages."
  echo "  --help               Display this help message."
  exit 0
}

# Default values
location=""
json_output_file=""
silent=false
api_key="" # Set your WeatherAPI key here

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --location)
    location="$2"
    shift
    ;;
  --api-key)
    api_key="$2"
    shift
    ;;
  --output)
    json_output_file="$2"
    shift
    ;;
  --silent) silent=true ;;
  --help) show_help ;;
  *)
    echo "Unknown parameter passed: $1"
    show_help
    ;;
  esac
  shift
done

$silent || echo "------------------------"
# Ensure API key is provided
if [[ -z "$api_key" ]]; then
  echo "WeatherAPI key is required."
  exit 1
fi

# Function to get location from coordinates
get_location_from_coordinates() {
  local coords
  coords=$(curl -s "http://ipinfo.io/loc")
  echo "$coords"
}

# Function to get external IP address
get_external_ip() {
  local ip
  ip=$(curl -s "https://api.ipify.org")
  echo "$ip"
}

# Determine location
if [[ -z "$location" ]]; then
  # Try to get location from coordinates
  location=$(get_location_from_coordinates)

  if [[ -z "$location" ]]; then
    # If coordinates could not be determined, get external IP
    external_ip=$(get_external_ip)

    if [[ -n "$external_ip" ]]; then
      location="$external_ip" # Use IP as the location
    else
      location="auto" # Fallback to "auto"
    fi
  fi
fi

# Fetch current weather data
weather_info=$(curl -s "http://api.weatherapi.com/v1/current.json?key=${api_key}&q=${location}&aqi=no")

# Check if request was successful
if [[ -z "$weather_info" || $(echo "$weather_info" | jq -r '.error') != "null" ]]; then
  echo "Failed to retrieve weather data for the location: $location"
  exit 1
fi

# Fetch astronomy data
astronomy_info=$(curl -s "http://api.weatherapi.com/v1/astronomy.json?key=${api_key}&q=${location}")

# Check if request was successful
if [[ -z "$astronomy_info" || $(echo "$astronomy_info" | jq -r '.error') != "null" ]]; then
  echo "Failed to retrieve astronomy data for the location: $location"
  exit 1
fi

# Parse the weather data
weather_condition=$(echo "$weather_info" | jq -r '.current.condition.text')
weather_code=$(echo "$weather_info" | jq -r '.current.condition.code')
uv_index=$(echo "$weather_info" | jq -r '.current.uv')
temperature=$(echo "$weather_info" | jq -r '.current.temp_c')
wind_speed=$(echo "$weather_info" | jq -r '.current.wind_kph')
last_updated=$(echo "$weather_info" | jq -r '.current.last_updated')

# Parse the astronomy info
sunrise=$(echo "$astronomy_info" | jq -r '.astronomy.astro.sunrise')
sunset=$(echo "$astronomy_info" | jq -r '.astronomy.astro.sunset')

# Check if parsed data is valid (i.e., non-empty values)
if [[ -z "$weather_condition" || -z "$uv_index" || -z "$sunrise" || -z "$sunset" ]]; then
  echo "Failed to parse weather or astronomy data."
  exit 1
fi

# Save the weather info in JSON format to a file if --output is provided
if [ -n "$json_output_file" ]; then
  echo "$weather_info" | jq '.' >>"$json_output_file"
  echo "JSON saved to: $json_output_file"
fi

# Get the current time in 12-hour format and convert AM/PM to uppercase
current_time=$(date +"%I:%M %p" | tr 'a-z' 'A-Z')

# Get the current installed theme
current_theme=$(gsettings get org.gnome.desktop.interface color-scheme)

# Set the UV index threshold for enabling the light theme (e.g., UV >= 6)
uv_threshold=0.1

# Specify your themes for light and dark modes
light_theme="prefer-light"
dark_theme="prefer-dark"

# Array of weather conditions that will trigger the dark theme
dark_conditions_codes=(
  # 1000  # Sunny
  # 1003  # Partly cloudy
  # 1006  # Cloudy
  1009 # Overcast
  # 1030 # Mist
  1063 # Patchy rain possible
  1066 # Patchy snow possible
  1069 # Patchy sleet possible
  1072 # Patchy freezing drizzle possible
  1087 # Thundery outbreaks possible
  1114 # Blowing snow
  1117 # Blizzard
  1135 # Fog
  1147 # Freezing fog
  1150 # Patchy light drizzle
  1153 # Light drizzle
  1168 # Freezing drizzle
  1171 # Heavy freezing drizzle
  1180 # Patchy light rain
  # 1183 # Light rain
  1186 # Moderate rain at times
  1189 # Moderate rain
  1192 # Heavy rain at times
  1195 # Heavy rain
  1198 # Light freezing rain
  1201 # Moderate or heavy freezing rain
  1204 # Light sleet
  1207 # Moderate or heavy sleet
  1210 # Patchy light snow
  1213 # Light snow
  1216 # Patchy moderate snow
  1219 # Moderate snow
  1222 # Patchy heavy snow
  1225 # Heavy snow
  1237 # Ice pellets
  # 1240 # Light rain shower
  1243 # Moderate or heavy rain shower
  1246 # Torrential rain shower
  1249 # Light sleet showers
  1252 # Moderate or heavy sleet showers
  1255 # Light snow showers
  1258 # Moderate or heavy snow showers
  1261 # Light showers of ice pellets
  1264 # Moderate or heavy showers of ice pellets
  1273 # Patchy light rain with thunder
  1276 # Moderate or heavy rain with thunder
  1279 # Patchy light snow with thunder
  1282 # Moderate or heavy snow with thunder
)

dark_conditions_descriptions=(
  # "Sunny"
  # "Partly cloudy"
  # "Cloudy"
  "Overcast"
  # "Mist"
  "Patchy rain possible"
  "Patchy snow possible"
  "Patchy sleet possible"
  "Patchy freezing drizzle possible"
  "Thundery outbreaks possible"
  "Blowing snow"
  "Blizzard"
  "Fog"
  "Freezing fog"
  "Patchy light drizzle"
  "Light drizzle"
  "Freezing drizzle"
  "Heavy freezing drizzle"
  "Patchy light rain"
  # "Light rain"
  "Moderate rain at times"
  "Moderate rain"
  "Heavy rain at times"
  "Heavy rain"
  "Light freezing rain"
  "Moderate or heavy freezing rain"
  "Light sleet"
  "Moderate or heavy sleet"
  "Patchy light snow"
  "Light snow"
  "Patchy moderate snow"
  "Moderate snow"
  "Patchy heavy snow"
  "Heavy snow"
  "Ice pellets"
  # "Light rain shower"
  "Moderate or heavy rain shower"
  "Torrential rain shower"
  "Light sleet showers"
  "Moderate or heavy sleet showers"
  "Light snow showers"
  "Moderate or heavy snow showers"
  "Light showers of ice pellets"
  "Moderate or heavy showers of ice pellets"
  "Patchy light rain with thunder"
  "Moderate or heavy rain with thunder"
  "Patchy light snow with thunder"
  "Moderate or heavy snow with thunder"
)

# Print current status if not silent
$silent || echo "Current Time: $current_time"
$silent || echo "Sunrise: $sunrise"
$silent || echo "Sunset: $sunset"
$silent || echo "UV Index: $uv_index"
$silent || echo "Weather Condition: $weather_condition"
$silent || echo "Location: $location"

# Print current weather data in a single line
$silent || echo "Current Weather: ${temperature}°C, Wind: ${wind_speed} km/h, Last Updated: $last_updated"

# Function to convert 12-hour format to minutes for comparison
time_to_minutes() {
  IFS=': ' read -r hour minute period <<<"$1"
  # Удаление ведущих нулей
  hour=$((10#$hour))     # Преобразование часов
  minute=$((10#$minute)) # Преобразование минут
  if [[ "$period" == "PM" && "$hour" -ne 12 ]]; then
    hour=$((hour + 12))
  elif [[ "$period" == "AM" && "$hour" -eq 12 ]]; then
    hour=0
  fi
  echo $((hour * 60 + minute))
}

# Convert current time to minutes for comparison
current_time_minutes=$(time_to_minutes "$current_time")

# Convert sunrise and sunset times to minutes for comparison
sunrise_minutes=$(time_to_minutes "$sunrise")
sunset_minutes=$(time_to_minutes "$sunset")

# Calculate noon as the average of sunrise and sunset
noon_minutes=$(((sunrise_minutes + sunset_minutes) / 2))

# Logic for choosing the theme

# Always check dark conditions, regardless of time
for i in "${!dark_conditions_codes[@]}"; do
  if [[ "$weather_code" -eq "${dark_conditions_codes[i]}" ]]; then
    # If weather conditions are dark, enable the dark theme
    if [[ "$current_theme" != "'$dark_theme'" ]]; then
      gsettings set org.gnome.desktop.interface color-scheme $dark_theme
      $silent || echo "Set dark theme due to weather condition: ${dark_conditions_descriptions[i]} (${dark_conditions_codes[i]})"
    fi
    exit
  fi
done

# If no dark conditions, proceed with time-based logic
if [[ "$current_time_minutes" -ge "$sunrise_minutes" && "$current_time_minutes" -le "$sunset_minutes" ]]; then
  if [[ "$current_time_minutes" -ge "$noon_minutes" ]]; then
    # After noon, check UV index
    if (($(echo "$uv_index >= $uv_threshold" | bc -l))); then
      # If UV index is high, set light theme
      if [[ "$current_theme" != "'$light_theme'" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme $light_theme
        $silent || echo "Set light theme due to UV index in the afternoon"
      fi
    else
      # If UV index is low, set dark theme
      if [[ "$current_theme" != "'$dark_theme'" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme $dark_theme
        $silent || echo "Set dark theme due to low UV index in the afternoon"
      fi
    fi
  else
    # Before noon, set light theme
    if [[ "$current_theme" != "'$light_theme'" ]]; then
      gsettings set org.gnome.desktop.interface color-scheme $light_theme
      $silent || echo "Set light theme in the morning"
    fi
  fi
else
  # If current time is not between sunrise and sunset, enable the dark theme
  if [[ "$current_theme" != "'$dark_theme'" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme $dark_theme
    $silent || echo "Set dark theme due to time"
  fi
fi
