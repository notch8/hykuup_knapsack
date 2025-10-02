# frozen_string_literal: true

module HykuKnapsack
  # CLI formatter for consistent, colorful output across rake tasks
  class CLIFormatter
    # Color and text formatting helpers
    def self.red(text); "\e[31m#{text}\e[0m"; end
    def self.green(text); "\e[32m#{text}\e[0m"; end
    def self.yellow(text); "\e[33m#{text}\e[0m"; end
    def self.blue(text); "\e[34m#{text}\e[0m"; end
    def self.magenta(text); "\e[35m#{text}\e[0m"; end
    def self.cyan(text); "\e[36m#{text}\e[0m"; end
    def self.bold(text); "\e[1m#{text}\e[0m"; end
    def self.underline(text); "\e[4m#{text}\e[0m"; end
    def self.bg_red(text); "\e[41m#{text}\e[0m"; end
    def self.bg_green(text); "\e[42m#{text}\e[0m"; end
    def self.bg_yellow(text); "\e[43m#{text}\e[0m"; end

    # Visual separators
    def self.separator(char = '=', length = 80); char * length; end
    def self.thick_separator; "=" * 80; end
    def self.thin_separator; "─" * 80; end

    # Status indicators
    def self.success_icon; green("✓"); end
    def self.error_icon; red("✗"); end
    def self.warning_icon; yellow("⚠"); end
    def self.info_icon; blue("ℹ"); end
    def self.arrow_icon; cyan("→"); end

    # Convenience methods for common formatting patterns
    def self.header(title, emoji = nil)
      title_with_emoji = emoji ? "#{emoji} #{title}" : title
      [
        thick_separator,
        bold(cyan("  #{title_with_emoji}")),
        thick_separator
      ]
    end

    def self.section_header(title, emoji = nil)
      title_with_emoji = emoji ? "#{emoji} #{title}" : title
      [
        "",
        bold(cyan("  #{title_with_emoji}")),
        thick_separator
      ]
    end

    def self.tenant_info(tenant_name, tenant_id, consortium = nil)
      [
        thin_separator,
        "#{arrow_icon} #{bold(tenant_name)}",
        "   #{info_icon} Tenant: #{tenant_id}",
        consortium ? "   #{info_icon} Consortium: #{consortium}" : "   #{info_icon} Consortium: None"
      ]
    end

    def self.status_line(icon, message, status = nil)
      status_text = status ? " #{status}" : ""
      "   #{icon} #{message}#{status_text}"
    end

    def self.error_section(title, items)
      return [] if items.empty?
      
      [
        "",
        bg_red("  #{title}"),
        red(thin_separator)
      ] + items.each_with_index.map do |item, index|
        [
          "",
          "#{red("#{index + 1}.")} #{bold(item[:tenant])}",
          "   #{error_icon} Error: #{red(item[:reason])}"
        ]
      end.flatten + [red(thin_separator)]
    end

    def self.warning_section(title, items)
      return [] if items.empty?
      
      [
        "",
        bg_yellow("  #{title}"),
        yellow(thin_separator)
      ] + items.each_with_index.map do |item, index|
        [
          "",
          "#{yellow("#{index + 1}.")} #{bold(item[:tenant])}",
          "   #{warning_icon} Reason: #{yellow(item[:reason])}"
        ]
      end.flatten + [yellow(thin_separator)]
    end

    def self.summary_stats(total, processed, success, skipped, errors)
      [
        "",
        "#{info_icon} #{bold('Statistics:')}",
        "   Total tenants: #{bold(total)}",
        "   Processed: #{bold(processed)}",
        "   #{success_icon} Successfully updated: #{green(bold(success))}",
        "   #{warning_icon} Skipped (validation failed): #{yellow(bold(skipped))}",
        "   #{error_icon} Errors: #{red(bold(errors))}"
      ]
    end

    def self.final_status(has_issues)
      if has_issues
        ["", red('❌ Some tenants had issues. See details above.')]
      else
        ["", green('✅ All tenants processed successfully!')]
      end
    end
  end
end
