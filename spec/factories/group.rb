FactoryBot.define do
    factory :group do
        company
        sequence(:name) { |n| "#{n}@example.com" }
    end
end