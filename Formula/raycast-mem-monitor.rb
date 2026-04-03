class RaycastMemMonitor < Formula
  desc "Monitor Raycast memory usage and restart it when it exceeds a threshold"
  homepage "https://github.com/ManicEuphoria/raycast_mem_monitor"
  head "https://github.com/ManicEuphoria/raycast_mem_monitor.git", branch: "main"
  license "MIT"

  def install
    libexec.install "raycast_mem_monitor.sh", "com.user.raycastmem.plist", "rmm"
    bin.install_symlink libexec/"rmm"
  end

  service do
    name macos: "homebrew.mxcl.raycast-mem-monitor"
    run [opt_bin/"rmm", "daemon"]
    keep_alive true
    working_dir Dir.home
    log_path var/"log/raycast-mem-monitor.log"
    error_log_path var/"log/raycast-mem-monitor.error.log"
  end

  test do
    fixture = testpath/"fixtures"
    app_dir = fixture/"IBM Notifier.app"
    notifier_bin = app_dir/"Contents/MacOS/IBM Notifier"
    zip_path = fixture/"IBM.Notifier.zip"
    release_json = fixture/"release.json"
    apps_dir = testpath/"Applications"

    notifier_bin.dirname.mkpath
    notifier_bin.write("#!/bin/bash\nexit 0\n")
    chmod 0755, notifier_bin
    system "/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app_dir, zip_path

    digest = Utils.safe_popen_read("/usr/bin/shasum", "-a", "256", zip_path.to_s).split.first
    release_json.write <<~JSON
      {
        "tag_name": "v-test",
        "name": "Test Release",
        "assets": [
          {
            "name": "IBM.Notifier.zip",
            "browser_download_url": "file://#{zip_path}",
            "digest": "sha256:#{digest}"
          }
        ]
      }
    JSON

    ENV["HOME"] = testpath.to_s
    ENV["RMM_NOTIFIER_PRIMARY_APP_ROOT"] = apps_dir.to_s
    ENV["RMM_NOTIFIER_FALLBACK_APP_ROOT"] = apps_dir.to_s
    ENV["RMM_NOTIFIER_LATEST_RELEASE_API"] = "file://#{release_json}"

    assert_match "install-notifier", shell_output("#{bin}/rmm help")
    output = shell_output("#{bin}/rmm install-notifier")
    assert_match "Installed IBM Notifier to:", output
    assert_predicate apps_dir/"IBM Notifier.app/Contents/MacOS/IBM Notifier", :exist?
    assert_match "already installed", shell_output("#{bin}/rmm -n")
  end
end
