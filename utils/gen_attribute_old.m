function attribute_serial_old=gen_attribute_old(attribute_serial)

    attribute_names = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Fidelity","Harmony", "Fair", "Ruddy"];
    attribute_names_old = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Precise reproduction","suit the environment or not", "white-skinned", "ruddy"];
    attribute_serial_old=attribute_serial;
    for i_attr=1:length(attribute_names)
        attribute_serial_old=strrep(attribute_serial_old, ...
            attribute_names(i_attr),attribute_names_old(i_attr));
    end
    
end