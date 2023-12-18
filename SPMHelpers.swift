// MARK: - Helpers: 2023-12-18 <- update the date when changing something.
fileprivate struct ExternalDependency {
	let packageDependency: Package.Dependency
	let targetDependency: Target.Dependency
	
	init(dependency: Package.Dependency, target: Target.Dependency) {
		self.packageDependency = dependency
		self.targetDependency = target
	}
	
	init(
		url: String,
		from version: String,
		name: String,
		moduleAliases: [String: String]? = nil,
		package: String
	) {
		self.packageDependency = .package(url: url, from: .init(stringLiteral: version))
		self.targetDependency = .product(name: name, package: package, moduleAliases: moduleAliases)
	}
	
	init(
		url: String,
		exact version: String,
		name: String,
		moduleAliases: [String: String]? = nil,
		package: String
	) {
		self.packageDependency = .package(url: url, exact: .init(stringLiteral: version))
		self.targetDependency = .product(name: name, package: package, moduleAliases: moduleAliases)
	}
	
	init(
		url: String,
		branch: String,
		name: String,
		moduleAliases: [String: String]? = nil,
		package: String
	) {
		self.packageDependency = .package(url: url, branch: branch)
		self.targetDependency = .product(name: name, package: package, moduleAliases: moduleAliases)
	}
	
	init(
		url: String,
		revision: String,
		name: String,
		moduleAliases: [String: String]? = nil,
		package: String
	) {
		self.packageDependency = .package(url: url, revision: revision)
		self.targetDependency = .product(name: name, package: package, moduleAliases: moduleAliases)
	}
	
	init(
		path: String,
		packageName: String? = nil,
		name: String,
		moduleAliases: [String: String]? = nil,
		package: String
	) {
		if let packageName {
			self.packageDependency = .package(name: packageName, path: path)
		} else {
			self.packageDependency = .package(path: path)
		}
		self.targetDependency = .product(name: name, package: package, moduleAliases: moduleAliases)
	}
}

extension Module {
	fileprivate enum Dependency {
		/// Modules defined in current Package
		case `internal`(Module)
		/// External Dependencies outside of this module
		case external(ExternalDependency)
		/// Add manually `Target.Dependency`
		///
		/// Usefull when adding some one shot dependency with some more complicated configuration.
		case additional(Target.Dependency)
	}
}

// NB: Make it simple for now. One Library, one target with the same name etc. Refactor when more option needed.
fileprivate struct Module {
	fileprivate let dependencies: [Dependency]
	private let _testTarget: TestTarget?
	fileprivate let name: String
	fileprivate let excludes: [String]
	fileprivate let resources: [Resource]?
	fileprivate let condition: TargetDependencyCondition?
	
	fileprivate init(
		name: String,
		dependencies: [Dependency] = [],
		testTarget: TestTarget? = nil,
		excludes: [String] = [],
		resources: [Resource]? = nil,
		condition: TargetDependencyCondition? = nil
	) {
		self.name = name
		self.dependencies = dependencies
		self._testTarget = testTarget
		self.excludes = excludes
		self.resources = resources
		self.condition = condition
	}
	
	var product: Product {
		.library(name: name, targets: [name])
	}
	
	var target: Target {
		let targetDependencies: [Target.Dependency] = dependencies.targetDependencies
		
		
		return .target(
			name: name,
			dependencies: targetDependencies,
			exclude: excludes,
			resources: resources
		)
	}
	
	var testTarget: Target? {
		guard let _testTarget else { return nil  }
		
		return .testTarget(
			name: _testTarget.name ?? name + "Tests",
			dependencies: [.byName(name: name)] + _testTarget.dependencies.targetDependencies,
			resources: _testTarget.resources
		)
	}
}

fileprivate struct TestTarget {
	let dependencies: [Module.Dependency]
	let name: String?
	let resources: [Resource]?
	
	init(
		name: String? = nil,
		dependencies: [Module.Dependency] = [],
		resources: [Resource]? = nil
	) {
		self.name = name
		self.dependencies = dependencies
		self.resources = resources
	}
	
	static let `default` = Self()
}

extension Package {
	fileprivate func setUpDependencies(_ dependencies: [ExternalDependency]) {
		self.dependencies = dependencies.map(\.packageDependency)
	}
	
	fileprivate func setUpModules(_ modules: [Module]) {
		self.products.append(contentsOf:  modules.map(\.product))
		self.targets.append(contentsOf: modules.map(\.target))
		self.targets.append(contentsOf: modules.compactMap(\.testTarget))
	}
}

fileprivate extension Array<Module.Dependency> {
	var targetDependencies: [Target.Dependency] {
		self.reduce(into: []) { partialResult, dependency in
			switch dependency {
			case let .internal(value):
				partialResult.append(Target.Dependency.target(name: value.name, condition: value.condition))
			case let .external(value):
				partialResult.append(value.targetDependency)
			case let .additional(value):
				partialResult.append(value)
			}
		}
	}
}

