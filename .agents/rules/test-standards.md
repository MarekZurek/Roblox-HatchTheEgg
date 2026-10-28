---
paths:
  - "tests/**"
  - "Assets/Tests/**/*.cs"
  - "Source/**/Tests/**/*.{h,cpp}"
---

# Test Standards

- Test naming follows the engine's language — every name says the scenario and
  the expected result:
  - **Godot (gdUnit4):** file `[system]_[feature]_test.gd`, function
    `test_[scenario]_[expected]`
  - **Unity (NUnit):** class `[System]Tests` in a file of the same name, method
    `[Scenario]_[Expected]` in PascalCase
  - **Roblox (TestEZ / Luau runner):** file `[System].spec.luau` or `tests/[suite]/run.luau`, scenario block `it("should [scenario] [expected]")`
  - **Unreal (Automation):** class `F[System][Scenario]Test` — one per test:
    each `IMPLEMENT_SIMPLE_AUTOMATION_TEST` defines its class, so a second test
    reusing a name fails to link — test name
    `<Project>.[System].[Scenario]` — the project's test command,
    `Automation RunTests <Project>.`, runs every test whose name contains
    `<Project>.` (a substring match, not a prefix). `<Project>.` is the root
    that filter in `commands.test` uses: the project name, or the distinct root
    `/setup-engine` chose when the project's name is also an engine area
    (`Audio`, `Core`, `Input`, …) — name tests under whichever it is
- Every test must have a clear arrange/act/assert structure
- Unit tests must not depend on external state (filesystem, network, database)
- Integration tests must clean up after themselves
- Performance tests must specify acceptable thresholds and fail if exceeded
- Test data must be defined in the test or in dedicated fixtures, never shared mutable state
- Mock external dependencies — tests should be fast and deterministic
- Every bug fix must have a regression test that would have caught the original bug —
  and **you must watch it fail before you trust it.** Run the new test against the
  unfixed code, confirm it fails, then apply the fix and confirm it passes. A
  regression test that has only ever been seen passing is not known to test anything.

  > This is `.claude/rules/skill-authoring.md`'s "a gate you have not watched fail
  > is not a gate", applied to tests. It is written out here because stating the
  > *goal* is not enough. A regression test for an iteration-order defect can use
  > a fixture where no cell takes part in two transfers per tick — it then passes
  > against the very bug it was written for, and looks authoritative doing it. The
  > fixture, not the assertion, is what makes it useless, and only running it
  > against the unfixed code exposes that.

## Examples

**Correct** (proper naming + Arrange/Act/Assert) — Godot, gdUnit4:

```gdscript
extends GdUnitTestSuite

func test_take_damage_reduces_health() -> void:
    # Arrange — auto_free: a Node left alive is an orphan (gdUnit4 exit 101)
    var health: HealthComponent = auto_free(HealthComponent.new())
    health.max_health = 100
    health.current_health = 100

    # Act
    health.take_damage(25)

    # Assert
    assert_int(health.current_health).is_equal(75)
```

Unity, NUnit (`Assets/Tests/EditMode/HealthTests.cs`):

```csharp
using NUnit.Framework;

public class HealthTests
{
    [Test]
    public void TakeDamage_ReducesHealth()
    {
        // Arrange
        var health = new Health(maxHealth: 100);

        // Act
        health.TakeDamage(25);

        // Assert
        Assert.AreEqual(75, health.Current);
    }
}
```

Unreal, Automation (`Source/<Module>/Private/Tests/HealthTest.cpp`):

```cpp
#include "Misc/AutomationTest.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FHealthTakeDamageTest, "<Project>.Health.TakeDamageReducesHealth",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FHealthTakeDamageTest::RunTest(const FString& Parameters)
{
    // Arrange
    FHealthPool Health(100);

    // Act
    Health.TakeDamage(25);

    // Assert
    TestEqual(TEXT("health after 25 damage"), Health.GetCurrent(), 75);
    return true;
}

#endif
```

Roblox, TestEZ / Luau:

```luau
return function()
    describe("HealthSystem", function()
        it("should reduce health on take_damage", function()
            -- Arrange
            local health = HealthComponent.new(100)

            -- Act
            health:take_damage(25)

            -- Assert
            expect(health.current_health).to.equal(75)
        end)
    end)
end
```

**Incorrect**:

```gdscript
func test1() -> void:  # VIOLATION: no descriptive name
    var h := HealthComponent.new()
    h.take_damage(25)  # VIOLATION: no arrange step, no clear assert
    assert_bool(h.current_health < 100).is_true()  # VIOLATION: imprecise assertion
```

## Roblox expected results and regression proof

Read [the Roblox testing contract](../../docs/workflow/ROBLOX_TESTING_CONTRACT.md). Cite the approved requirement, section/revision and independent derivation of each relevant expectation. Do not call the tested function to produce its expected value, or silently regenerate acceptance expectations from an implementation change. Catalogue consistency remains useful but must not be presented as independent spec/pricing validation.

Retain the unfixed revision or isolated semantic fault, exact command, intended failing assertion/exit, and corrected PASS. Syntax/import failure, timeout or an unrelated assertion is INVALID evidence; a faulty implementation that passes is SURVIVED. A regression only observed passing remains INCOMPLETE. In Luau review do/for cases and meaningful observations, not a fixed assertion quota per helper function.
