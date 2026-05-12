class Dalejdalej < Formula
  desc "Monitor GitHub PRs with Claude AI — auto-rebase and CI triage"
  homepage "https://github.com/Trurls/homebrew-dalejdalej"
  url "https://github.com/Trurls/homebrew-dalejdalej/archive/refs/tags/v0.0.7.tar.gz"
  sha256 "fc7edf29a13875d61e2815e3216494be81004054e0ca7b9da7b71e485670552e"
  license "MIT"
  head "ssh://git@github-personal/Trurls/homebrew-dalejdalej.git", branch: "main"

  depends_on "fzf"
  depends_on "jq"
  depends_on "yq"

  def install
    bin.install "bin/dalejdalej"
    libexec.install Dir["libexec/*"]
    chmod 0755, Dir[libexec/"*.sh"]
    chmod 0755, "claude/hooks/allowlist.sh"
    prefix.install "claude"
  end

  service do
    run opt_libexec/"dalejdalej-daemon.sh"
    log_path var/"log/dalejdalej.log"
    error_log_path var/"log/dalejdalej.log"
    run_type :interval
    interval 1800
  end

  def caveats
    <<~EOS
      Config lives at ~/.dalejdalej.yaml (created on first `dalejdalej add`).
      Cloned repos land in ~/dalejdalej/<repo-name>/.

      Start the background daemon:
        brew services start dalejdalej

      Or manage manually:
        dalejdalej start|stop|status|logs
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/dalejdalej 2>&1", 1)
  end
end
