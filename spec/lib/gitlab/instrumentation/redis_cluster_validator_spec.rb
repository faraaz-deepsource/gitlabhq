# frozen_string_literal: true

require 'fast_spec_helper'
require 'support/helpers/rails_helpers'
require 'rspec-parameterized'

RSpec.describe Gitlab::Instrumentation::RedisClusterValidator do
  include RailsHelpers

  describe '.validate!' do
    using RSpec::Parameterized::TableSyntax

    where(:command, :arguments, :should_raise) do
      :rename | %w(foo bar) | true
      :RENAME | %w(foo bar) | true
      'rename' | %w(foo bar) | true
      'RENAME' | %w(foo bar) | true
      :rename | %w(iaa ahy) | false # 'iaa' and 'ahy' hash to the same slot
      :rename | %w({foo}:1 {foo}:2) | false
      :rename | %w(foo foo bar) | false # This is not a valid command but should not raise here
      :mget | %w(foo bar) | true
      :mget | %w(foo foo bar) | true
      :mget | %w(foo foo) | false
      :blpop | %w(foo bar 1) | true
      :blpop | %w(foo foo 1) | false
      :mset | %w(foo a bar a) | true
      :mset | %w(foo a foo a) | false
      :del | %w(foo bar) | true
      :del | [%w(foo bar)] | true # Arguments can be a nested array
      :del | %w(foo foo) | false
      :hset | %w(foo bar) | false # Not a multi-key command
      :mget | [] | false # This is invalid, but not because it's a cross-slot command
    end

    with_them do
      it do
        args = [[command] + arguments]

        if should_raise
          expect { described_class.validate!(args) }
            .to raise_error(described_class::CrossSlotError)
        else
          expect { described_class.validate!(args) }.not_to raise_error
        end
      end
    end

    where(:arguments, :should_raise) do
      [[:get, "foo"], [:get, "bar"]] | true
      [[:get, "foo"], [:mget, "foo", "bar"]] | true # mix of single-key and multi-key cmds
      [[:get, "{foo}:name"], [:get, "{foo}:profile"]] | false
      [[:del, "foo"], [:del, "bar"]] | true
      [] | false # pipeline or transaction opened and closed without ops
    end

    with_them do
      it do
        if should_raise
          expect { described_class.validate!(arguments) }
            .to raise_error(described_class::CrossSlotError)
        else
          expect { described_class.validate!(arguments) }.not_to raise_error
        end
      end
    end
  end

  describe '.allow_cross_slot_commands' do
    it 'does not raise for invalid arguments' do
      expect do
        described_class.allow_cross_slot_commands do
          described_class.validate!([[:mget, 'foo', 'bar']])
        end
      end.not_to raise_error
    end

    it 'allows nested invocation' do
      expect do
        described_class.allow_cross_slot_commands do
          described_class.allow_cross_slot_commands do
            described_class.validate!([[:mget, 'foo', 'bar']])
          end

          described_class.validate!([[:mget, 'foo', 'bar']])
        end
      end.not_to raise_error
    end
  end
end
