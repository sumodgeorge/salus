require_relative '../../spec_helper'
require 'json'

describe Sarif::BrakemanSarif do
  describe '#parse_issue' do
    let(:scanner) { Salus::Scanners::Brakeman.new(repository: repo, config: { 'path' => path }) }
    before { scanner.run }

    context 'scan report with logged vulnerabilites' do
      let(:repo) { Salus::Repo.new('spec/fixtures') }
      let(:path) { '/home/spec/fixtures/brakeman/vulnerable_rails_app' }
      it 'parses information correctly' do
        brakeman_sarif = Sarif::BrakemanSarif.new(scanner.report)
        issue = JSON.parse(scanner.log(''))['warnings'][0]

        brakeman_sarif.build_runs_object(true)
        expect(brakeman_sarif.parse_issue(issue)).to include(
          id: "13",
          name: "Evaluation/Dangerous Eval",
          level: "HIGH",
          details: "User input in eval",
          messageStrings: { "confidence": { "text": "High" },
                           "title": { "text": "Evaluation" },
                           "type": { "text": "Dangerous Eval" },
                           "warning_code": { "text": "13" },
                           "fingerprint": { "text": "b16e1cd0d9524"\
                           "33f80b0403b6a74aab0e98792ea015cc1b1fa5c003cbe7d56eb" } },
          start_line: 3,
          start_column: 1,
          help_url: "https://brakemanscanner.org/docs/warning_types/dangerous_eval/",
          code: "eval(params[:evil])",
          uri: "app/controllers/static_controller_controller.rb"
        )
      end

      it 'should parse brakeman errors' do
        brakeman_sarif = Sarif::BrakemanSarif.new(scanner.report)
        error = { 'error' => 'foo', 'location' => 'fooclass' }.stringify_keys
        parsed_error = brakeman_sarif.parse_issue(error)
        expect(parsed_error[:id]).to eq('SAL002')
        expect(parsed_error[:name]).to eq('Brakeman Error')
        expect(parsed_error[:level]).to eq('HIGH')
        expect(parsed_error[:details]).to eq('foo')
        expect(parsed_error[:uri]).to eq('fooclass')
      end
    end
  end

  describe '#build_result' do
    context 'rails project with vulnerabilities' do
      it 'should generate valid result for a brakeman warning with no code snippets' do
        scan_report = Salus::ScanReport.new('Brakeman')
        scan_report.add_version('0.1')
        brakeman_sarif = Sarif::BrakemanSarif.new(scan_report)
        issue = {
          "warning_type": "Cross-Site Request Forgery",
          "warning_code": 116,
          "fingerprint": "ssshhhhsa",
          "check_name": "CSRFTokenForgeryCVE",
          "message": "Rails 5.0.0 has a vulnerability that may allow CSRF token forgery.",
          "file": "Gemfile",
          "line": 5,
          "link": "https://groups.google.com/g/rubyonrails-security/c/NOjKiGeXUgw",
          "code": nil,
          "render_path": nil,
          "location": nil,
          "user_input": nil,
          "confidence": "Medium"
        }.stringify_keys
        parsed_issue = brakeman_sarif.parse_issue(issue)
        result = brakeman_sarif.build_result(parsed_issue)
        location = result[:locations][0][:physicalLocation]
        expect(location[:region][:snippet].nil?).to eq(true)
        expect(location[:region][:startLine].nil?).to eq(false)
      end

      it 'should generate valid result for a brakeman warning with code snippets' do
        scan_report = Salus::ScanReport.new('Brakeman')
        scan_report.add_version('0.1')
        brakeman_sarif = Sarif::BrakemanSarif.new(scan_report)
        issue = {
          "warning_type": "Cross-Site Request Forgery",
          "warning_code": 116,
          "fingerprint": "ssshhhhsa",
          "check_name": "CSRFTokenForgeryCVE",
          "message": "Rails 5.0.0 has a vulnerability that may allow CSRF token forgery.",
          "file": "Gemfile",
          "line": 5,
          "link": "https://groups.google.com/g/rubyonrails-security/c/NOjKiGeXUgw",
          "code": '1 puts hello',
          "render_path": nil,
          "location": nil,
          "user_input": nil,
          "confidence": "Medium"
        }.stringify_keys
        parsed_issue = brakeman_sarif.parse_issue(issue)
        result = brakeman_sarif.build_result(parsed_issue)
        location = result[:locations][0][:physicalLocation]
        expect(location[:region][:snippet][:text]).to eq("1 puts hello")
      end
    end
  end

  describe '#sarif_level' do
    it 'should map brakeman severity/confidence levels to sarif_levels' do
      scan_report = Salus::ScanReport.new('Brakeman')
      scan_report.add_version('0.1')
      brakeman_adapter = Sarif::BrakemanSarif.new(scan_report)
      expect(brakeman_adapter.sarif_level('HIGH')).to eq('error')
      expect(brakeman_adapter.sarif_level('MEDIUM')).to eq('error')
      expect(brakeman_adapter.sarif_level('LOW')).to eq('warning')
      expect(brakeman_adapter.sarif_level('WEAK')).to eq('note')
    end
  end
  describe '#sarif_report' do
    let(:scanner) { Salus::Scanners::Brakeman.new(repository: repo, config: {}) }
    before { scanner.run }

    context 'non rails project' do
      let(:repo) { Salus::Repo.new('spec/fixtures/blank_repository') }
      it 'should handle generated error' do
        report = Salus::Report.new(project_name: "Neon Genesis")
        report.add_scan_report(scanner.report, required: false)
        report_object = JSON.parse(report.to_sarif)['runs'][0]
        expect(report_object['invocations'][0]['executionSuccessful']).to eq(false)

        message = report_object['invocations'][0]['toolExecutionNotifications'][0]['message']
        expect(message['text']).to include('brakeman exited with an unexpected exit status')
      end
    end

    context 'rails project with no vulnerabilities' do
      let(:repo) { Salus::Repo.new('/home/spec/fixtures/brakeman/bundler_2') }
      it 'should generate an empty sarif report' do
        report = Salus::Report.new(project_name: "Neon Genesis")
        report.add_scan_report(scanner.report, required: false)
        report_object = JSON.parse(report.to_sarif)['runs'][0]

        expect(report_object['invocations'][0]['executionSuccessful']).to eq(true)
      end
    end

    context 'python project with empty report containing whitespace' do
      let(:repo) { Salus::Repo.new('/home/spec/fixtures/brakeman/bundler_2') }
      it 'should handle empty reports with whitespace' do
        report = Salus::Report.new(project_name: "Neon Genesis")
        # Override the report.log() to return "\n"
        report.class.send(:define_method, :log, -> { "\n" })
        expect_any_instance_of(Sarif::BrakemanSarif).not_to receive(:bugsnag_notify)

        report.add_scan_report(scanner.report, required: false)
        report_object = JSON.parse(report.to_sarif)['runs'][0]
        expect(report_object['invocations'][0]['executionSuccessful']).to eq(true)
      end
    end

    context 'rails project with vulnerabilities' do
      let(:repo) { Salus::Repo.new('/home/spec/fixtures/brakeman/vulnerable_rails_app') }
      it 'should generate the right results and rules' do
        report = Salus::Report.new(project_name: "Neon Genesis")
        report.add_scan_report(scanner.report, required: false)
        result = JSON.parse(report.to_sarif)["runs"][0]["results"][0]
        rules = JSON.parse(report.to_sarif)["runs"][0]["tool"]["driver"]["rules"]
        # Check rule info
        expect(rules[0]['id']).to eq('13')
        expect(rules[0]['name']).to eq('Evaluation/Dangerous Eval')
        expect(rules[0]['fullDescription']['text']).to eq("User input in eval")
        expect(rules[0]['helpUri']).to eq('https://brakemanscanner.org/docs/warning_types'\
          '/dangerous_eval/')

        # Check result info
        expect(result['ruleId']).to eq('13')
        expect(result['ruleIndex']).to eq(0)
        expect(result['level']).to eq('error')
        expect(result['locations'][0]['physicalLocation']['region']['startLine']).to eq(3)
        snippet = result['locations'][0]['physicalLocation']['region']['snippet']['text'].to_s
        expect(snippet).to eq("eval(params[:evil])")
      end
    end
  end
end
