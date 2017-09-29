# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flows::Executor do
  subject(:execution) { described_class.call(schema, input) }

  let(:do_upcase) do
    lambda do |x|
      x.upcase
    end
  end

  let(:do_reverse) do
    lambda do |x|
      x.reverse
    end
  end

  let(:is_word) do
    lambda do |x|
      x.strip.casecmp('word').zero? ? [:yes, x] : [:no, x]
    end
  end

  context 'with one-node schema with upcasing logic and "awesome"::String as an incoming data' do
    let(:schema) do
      [
        :upcase,
        {
          upcase: [
            do_upcase,
            :exit
          ],
          exit: :ok
        }
      ]
    end

    let(:input) { 'awesome' }

    it 'returns [:ok, AWESOME]' do
      is_expected.to eq [:ok, 'AWESOME']
    end
  end

  context 'with empty schema' do
    let(:schema) do
      [
        :enter,
        {
          enter: :ok
        }
      ]
    end

    let(:input) { 'who cares?' }

    it 'returns [:ok, \'who cares?\']' do
      is_expected.to eq [:ok, input]
    end
  end

  context 'with conditional schema (2 possible paths)' do
    let(:schema) do
      [
        :is_word,
        {
          is_word: [
            is_word,
            {
              yes: :do_upcase,
              no:  :do_reverse
            }
          ],
          do_upcase: [
            do_upcase,
            :exit
          ],
          do_reverse: [
            do_reverse,
            :exit
          ],
          exit: :ok
        }
      ]
    end

    context 'when first path should be chosen' do
      let(:input) { 'Word' }

      it 'first path executed' do
        is_expected.to eq [:ok, input.upcase]
      end
    end

    context 'when second path should be chosen' do
      let(:input) { 'bullshit' }

      it 'second path executed' do
        is_expected.to eq [:ok, input.reverse]
      end
    end
  end
end
