function attribute_serial_new=gen_attribute_new(attribute_serial)
    attribute_names = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Precise reproduction","suit the environment or not", "white-skinned", "ruddy"];
    attribute_names_new = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Fidelity","Harmony", "Fair", "Ruddy"];
    attribute_serial_new=attribute_serial;
    for i_attr=1:length(attribute_names)
        attribute_serial_new=strrep(attribute_serial_new, ...
            attribute_names(i_attr),attribute_names_new(i_attr));
    end
    
end