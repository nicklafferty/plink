#!/bin/zsh
set -euo pipefail

APP_NAME="Plink"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"
WORKFLOW_DIR="$HOME/Library/Services/Convert HEIC to JPG.workflow"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PBS="/System/Library/CoreServices/pbs"

"$ROOT_DIR/build.sh"

if pgrep -x Plink >/dev/null 2>&1; then
  pkill -x Plink || true
fi

rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

rm -rf "$WORKFLOW_DIR"
mkdir -p "$WORKFLOW_DIR/Contents/Resources"
cat > "$WORKFLOW_DIR/Contents/Info.plist" <<'WORKFLOW_INFO'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en_US</string>
	<key>CFBundleIdentifier</key>
	<string>com.nicklafferty.heicdrop.quickaction</string>
	<key>CFBundleName</key>
	<string>Convert HEIC to JPG</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Convert HEIC to JPG</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSApplicationIdentifier</key>
				<string>com.apple.finder</string>
			</dict>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.heic</string>
				<string>public.heif</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
WORKFLOW_INFO

cat > "$WORKFLOW_DIR/Contents/Resources/document.wflow" <<'WORKFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>COMMAND_STRING</key>
					<string><![CDATA[
converter="/Applications/Plink.app/Contents/MacOS/Plink"

for file in "$@"; do
  lower="$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *.heic|*.heif)
      "$converter" --convert "$file" >/dev/null
      ;;
  esac
done

open -a "/Applications/Plink.app" >/dev/null 2>&1 || true
]]></string>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/zsh</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<false/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.path</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMParameterProperties</key>
				<dict>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.path</string>
					</array>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>F9E00B0E-3D57-4212-8C41-22F3053E59E3</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
				</array>
				<key>OutputUUID</key>
				<string>6487AA98-2105-42E8-9C78-E1D6CB60CB58</string>
				<key>UUID</key>
				<string>F3B92942-6692-44C4-A58D-C222CA1B0D49</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict/>
				<key>isViewVisible</key>
				<true/>
				<key>nibPath</key>
				<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/main.nib</string>
			</dict>
			<key>isViewVisible</key>
			<true/>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>state</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>serviceApplicationBundleID</key>
		<string></string>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject.image</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WORKFLOW
plutil -convert binary1 "$WORKFLOW_DIR/Contents/Resources/document.wflow"
plutil -convert binary1 "$WORKFLOW_DIR/Contents/Info.plist"

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$TARGET_APP" >/dev/null 2>&1 || true
fi

if [[ -x "$PBS" ]]; then
  "$PBS" -update en >/dev/null 2>&1 || true
fi

LOGIN_STATUS="Launch at login is enabled."
if ! osascript <<'APPLESCRIPT' >/dev/null 2>&1
tell application "System Events"
  if exists login item "Plink" then
    set path of login item "Plink" to "/Applications/Plink.app"
    set hidden of login item "Plink" to false
  else
    make login item at end with properties {name:"Plink", path:"/Applications/Plink.app", hidden:false}
  end if
end tell
APPLESCRIPT
then
  LOGIN_STATUS="Installed, but macOS blocked setting the login item automatically. Add Plink in System Settings > General > Login Items."
fi

open "$TARGET_APP"

echo "Installed $TARGET_APP"
echo "$LOGIN_STATUS"
echo "Installed Quick Action: $WORKFLOW_DIR"
echo "Right-click HEIC files in Finder, then use Quick Actions > Convert HEIC to JPG."
