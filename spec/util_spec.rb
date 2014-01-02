require 'spec_helper'

describe 'Geomodel::Util' do
  
  it 'can merge and sort one or many arrays into a target array' do
    list1 = [0, 1, 5, 6, 8, 9, 15]
    list2 = [0, 2, 3, 5, 8, 10, 11, 17]
    list3 = [1, 4, 6, 8, 10, 15, 16]
    list4 = [-1, 19]
    list5 = [20]
    list6 = []
    
    
    Geomodel::Util.merge_in_place(list1, [list2, list3, 
                                  list4, list5, list6], lambda { |x| x })

    expect(list1).to eq([-1, 0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 15, 16, 17, 19, 20])
  end
end