allprojects {
    repositories {
        google()
        mavenCentral()
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureJava: (Project) -> Unit = { p ->
        val androidExt = p.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (e: Throwable) {}
        }
        p.tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        p.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    if (state.executed) {
        configureJava(this)
    } else {
        afterEvaluate {
            configureJava(this)
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
