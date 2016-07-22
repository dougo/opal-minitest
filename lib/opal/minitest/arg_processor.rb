module Opal
  module Minitest
    class ArgProcessor
      def self.process_args args = [] # :nodoc:
        options = {}
        orig_args = args.dup

        OptionParser.new do |opts|
          opts.banner  = "minitest options:"
          opts.program_name = "minitest"
          # PORT: changed
          # opts.version = Minitest::VERSION
          opts.version = "5.3.4.opal"
          
          opts.on "-h", "--help", "Display this help." do
            puts opts
            exit
          end
          
          opts.on "-s", "--seed SEED", Integer, "Sets random seed" do |m|
            options[:seed] = m.to_i
          end
          
          opts.on "-v", "--verbose", "Verbose. Show progress processing files." do
            options[:verbose] = true
          end
          
          opts.on "-n", "--name PATTERN","Filter run on /pattern/ or string." do |a|
            options[:filter] = a
          end
          
          # PORT: unsupported
#         unless extensions.empty?
#           opts.separator ""
#           opts.separator "Known extensions: #{extensions.join(', ')}"
#
#           extensions.each do |meth|
#             msg = "plugin_#{meth}_options"
#             send msg, opts, options if self.respond_to?(msg)
#           end
#         end

          begin
            opts.parse! args
          rescue OptionParser::InvalidOption => e
            puts
            puts e
            puts
            puts opts
            exit 1
          end

          orig_args -= args
        end

        options[:orig_args] = orig_args

        options
      end
    end
  end
end
