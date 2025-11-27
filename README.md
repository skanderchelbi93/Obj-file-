       DeclareLaunchArgument(
            'mesh_file_path',
            default_value='/workspaces/models/textured_mesh.obj',
            description='The absolute file path to the mesh file'),

        DeclareLaunchArgument(
            'texture_path',
            default_value='/workspaces/models/material_0.png',
            description='The absolute file path to the texture map'),

        DeclareLaunchArgument(
            'refine_model_file_path',
            default_value=REFINE_MODEL_PATH,
            description='The absolute file path to the refine model'),

        DeclareLaunchArgument(
            'refine_engine_file_path',
            default_value=REFINE_ENGINE_PATH,
            description='The absolute file path to the refine trt engine'),
