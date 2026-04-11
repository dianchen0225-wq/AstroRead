import abilityTest from './Ability.test';
import EnhancedRuleEngineTest from './EnhancedRuleEngine.test';
import ViewModelTest from './ViewModelTest.test';
import PerformanceTest from './PerformanceTest.test';

export default function testsuite() {
  abilityTest();
  EnhancedRuleEngineTest();
  ViewModelTest();
  PerformanceTest();
}
