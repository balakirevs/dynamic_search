require 'spec_helper'

describe DynamicSearch::Processor do
  describe 'scope' do
    let(:scope) {
      double('scope').tap do |mock_scope|
        allow(mock_scope).to receive(:merge)
      end
    }
    let(:params) {
      {
        '0' => {key: 'name', operator: 'operator', value: 'value'}
      }
    }
    let(:config) {
      {
        name: {}
      }
    }

    let(:processor) { DynamicSearch::Processor.new(scope, params, config) }

    it 'loops through params.values' do
      expect(params).to receive(:values) { [] }
      processor.scope
    end

    context 'when DynamicSearch::Query#scope returns falsy value' do
      it 'is not merged to scope' do
        allow_any_instance_of(DynamicSearch::Query).to receive(:scope) { nil }
        expect(scope).not_to receive(:merge)
        processor.scope
      end
    end

    context 'when DynamicSearch::Query#scope returns truthy value' do
      it 'is merged to scope' do
        allow_any_instance_of(DynamicSearch::Query).to receive(:scope) { {} }
        expect(scope).to receive(:merge).with({})
        processor.scope
      end
    end
  end
end
