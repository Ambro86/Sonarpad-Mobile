allprojects {
    repositories {
        google()
        mavenCentral {
            // AndroidX artifacts are published by Google's Maven repository.
            // Keeping them out of Maven Central also prevents Gradle from
            // querying dynamic AndroidX metadata there (and hitting HTTP 429).
            content {
                excludeGroupByRegex("androidx\\..*")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Flutter's integration_test plugin still requests androidx.test:runner
    // with a dynamic version (1.2+). A dynamic selector forces Gradle to read
    // maven-metadata.xml during a release build and can fail on transient
    // repository throttling. Pin the current stable runner before resolution.
    configurations.configureEach {
        resolutionStrategy.force("androidx.test:runner:1.7.0")
    }

    afterEvaluate {
        if (project.hasProperty("android")) {
            dependencies {
                "implementation"("androidx.concurrent:concurrent-futures:1.1.0")
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
