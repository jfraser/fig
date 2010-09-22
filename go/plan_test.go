package fig

import "testing"

func TestNoDependencies(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, NewPackageBuilder("foo", "1.2.3").Config("default").End().Build())
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	if len(configs) != 1 {
		t.Errorf("Expected 1 config, got: %d", len(configs))
	}
}

func TestSimpleDependency(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("default").Include("bar", "4.5.6", "default").End().
		Build()
	bar := NewPackageBuilder("bar", "4.5.6").
		Config("default").End().
		Build()
	WritePackage(repo, foo)
	WritePackage(repo, bar)
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	if len(configs) != 2 {
		t.Errorf("Expected 2 configs, got: %d", len(configs))
	}
}

func TestTransitiveDependency(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("default").Include("bar", "4.5.6", "default").End().
		Build()
	bar := NewPackageBuilder("bar", "4.5.6").
		Config("default").Include("baz", "7.8.9", "default").End().
		Build()
	baz := NewPackageBuilder("baz", "7.8.9").
		Config("default").End().
		Build()
	WritePackage(repo, foo)
	WritePackage(repo, bar)
	WritePackage(repo, baz)
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	if len(configs) != 3 {
		t.Errorf("Expected 3 configs, got: %d", len(configs))
	}
}

func TestDiamondDependency(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("default").Include("bar", "4.5.6", "default").Include("baz", "7.8.9", "default").End().
		Build()
	bar := NewPackageBuilder("bar", "4.5.6").
		Config("default").Include("util", "0.0.0", "default").End().
		Build()
	baz := NewPackageBuilder("baz", "7.8.9").
		Config("default").Include("util", "0.0.0", "default").End().
		Build()
	util := NewPackageBuilder("util", "0.0.0").
		Config("default").End().
		Build()
	WritePackage(repo, foo)
	WritePackage(repo, bar)
	WritePackage(repo, baz)
	WritePackage(repo, util)
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	checkDescriptors(t, configs, []Descriptor{
		NewDescriptor("util", "0.0.0", "default"),
		NewDescriptor("bar", "4.5.6", "default"),
		NewDescriptor("baz", "7.8.9", "default"),
		NewDescriptor("foo", "1.2.3", "default")})
}

func TestRepeatedAtDifferentDepthsDependency(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("default").Include("baz", "7.8.9", "default").Include("bar", "4.5.6", "default").End().
		Build()
	bar := NewPackageBuilder("bar", "4.5.6").
		Config("default").Include("util", "0.0.0", "default").Include("baz", "7.8.9", "default").End().
		Build()
	baz := NewPackageBuilder("baz", "7.8.9").
		Config("default").Include("util", "0.0.0", "default").End().
		Build()
	util := NewPackageBuilder("util", "0.0.0").
		Config("default").End().
		Build()
	WritePackage(repo, foo)
	WritePackage(repo, bar)
	WritePackage(repo, baz)
	WritePackage(repo, util)
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	checkDescriptors(t, configs, []Descriptor{
		NewDescriptor("util", "0.0.0", "default"),
		NewDescriptor("baz", "7.8.9", "default"),
		NewDescriptor("bar", "4.5.6", "default"),
		NewDescriptor("foo", "1.2.3", "default")})
}

func TestMultipleConfigsInSamePackage(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("default").Include("foo", "1.2.3", "debug").End().
		Config("debug").End().
		Build()
	WritePackage(repo, foo)
	planner := NewPlanner(repo)
	configs, err := planner.Plan(NewDescriptor("foo","1.2.3","default"))
	if err != nil {
		t.Fatal(err)
	}
	checkDescriptors(t, configs, []Descriptor{
		NewDescriptor("foo", "1.2.3", "debug"),
		NewDescriptor("foo", "1.2.3", "default")})
}

/*
func TestCyclicSingleDependency(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("a").Include("foo", "1.2.3", "a").End().
		Build()
	WritePackage(repo, foo)
	planner := NewPlanner(repo)
	_, err := planner.Plan(NewDescriptor("foo","1.2.3","a"))
	if err == nil {
		t.Fatal("expected cyclic dependency error")
	}
}
*/

func TestCyclicDependencyTwoNodes(t *testing.T) {
	repo := NewMemoryRepository()
	foo := NewPackageBuilder("foo", "1.2.3").
		Config("a").Include("foo", "1.2.3", "b").End().
		Config("b").Include("foo", "1.2.3", "a").End().
		Build()
	WritePackage(repo, foo)
	planner := NewPlanner(repo)
	_, err := planner.Plan(NewDescriptor("foo","1.2.3","a"))
	if err == nil {
		t.Fatal("expected cyclic dependency error")
	}
	cyclicErr := err.(*CyclicDependencyError)
	checkDescriptors(t, cyclicErr.Cycle, []Descriptor{
		NewDescriptor("foo", "1.2.3", "a"),
		NewDescriptor("foo", "1.2.3", "b"),
	})
}

// TestVersionConflictError.String()
// TestCyclicDependencyError.String()
// TestPackageNotFound
// TestConfigNotFound

func checkDescriptors(t *testing.T, actual []Descriptor, expected []Descriptor) {
	if len(expected) != len(actual) {
		t.Fatalf("Expected %v, got: %v", expected, actual)
	}
	for  i, desc := range actual {
		if !desc.Equals(expected[i]) {
			t.Fatalf("Expected %v, got: %v", expected, actual)			
		}
	}
}
